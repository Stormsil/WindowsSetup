# ==========================================================
# CONFIGURATION
# ==========================================================
$MainPcDeviceId = "CWLGB4P-HYN2JK3-MQ7MMOE-Q4LKMJS-RVUP3BW-RWPF6J5-YIMHUQU-K3UX7AH"
$MainPcName     = "Main-Desktop-PC"
$FolderId       = "GlobalSync" 
$SyncFolderPath = "C:\Sync"

function Write-Log {
    param($Msg, $Col = "White")
    Write-Host "[SyncThing] $Msg" -ForegroundColor $Col
}

# ==========================================================
# 1. FIND ACTUAL BINARY & FIREWALL
# ==========================================================
Write-Log "--- STEP 1: FIREWALL & BINARY ---" "Cyan"

$standardPaths = @(
    "C:\Program Files\Syncthing\syncthing.exe",
    "C:\Program Files (x86)\Syncthing\syncthing.exe",
    "$env:ProgramData\Syncthing\syncthing.exe"
)

$realExe = $null
foreach ($path in $standardPaths) {
    if (Test-Path $path) {
        $realExe = $path
        break
    }
}

if (!$realExe) { $realExe = (Get-Command "syncthing.exe" -ErrorAction SilentlyContinue).Source }

if (!$realExe) {
    Write-Error "Syncthing not found!"
    Read-Host "Press Enter to exit..."
    exit
}

# Open Firewall for the specific EXE
Get-NetFirewallRule -DisplayName "Syncthing*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName "Syncthing - App Access" -Direction Inbound -Program $realExe -Action Allow -Profile Any -Enabled True | Out-Null
New-NetFirewallRule -DisplayName "Syncthing - App Outbound" -Direction Outbound -Program $realExe -Action Allow -Profile Any -Enabled True | Out-Null

Write-Host "Binary found and Firewall rules applied." -ForegroundColor Green

# ==========================================================
# 2. INITIALIZATION
# ==========================================================
Write-Host "`n--- STEP 2: STARTING FOR CONFIGURATION ---" -ForegroundColor Cyan
$configFolder = "$env:LOCALAPPDATA\Syncthing"
if (!(Test-Path $configFolder)) { New-Item -ItemType Directory -Path $configFolder -Force | Out-Null }

# Kill any existing process
Stop-Process -Name "syncthing" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Start Syncthing
$proc = Start-Process $realExe -ArgumentList "--no-browser", "--no-restart", "--home=$configFolder" -PassThru -WindowStyle Hidden

Write-Host "Waiting for config.xml..."
$configPath = Join-Path $configFolder "config.xml"
$timer = 0
while (!(Test-Path $configPath) -and $timer -lt 40) {
    Start-Sleep -Seconds 2
    $timer += 2
}

# ==========================================================
# 3. REST API SETUP
# ==========================================================
[xml]$xmlConfig = Get-Content $configPath
$apiKey = $xmlConfig.configuration.gui.apikey
$apiUrl = "http://127.0.0.1:8384/rest"
$headers = @{ "X-API-Key" = $apiKey }

Write-Host "Connecting to API..."
while ($true) {
    try {
        $res = Invoke-RestMethod -Uri "$apiUrl/system/ping" -Headers $headers -Method Get
        if ($res.ping -eq "pong") { break }
    } catch { Start-Sleep -Seconds 2 }
}

# ==========================================================
# 4. APPLY CONFIGURATION
# ==========================================================
Write-Host "`n--- STEP 3: APPLYING SETTINGS ---" -ForegroundColor Cyan
$currentConfig = Invoke-RestMethod -Uri "$apiUrl/system/config" -Headers $headers -Method Get

# Device Logic
$deviceExists = $currentConfig.devices | Where-Object { $_.deviceID -eq $MainPcDeviceId }
if (!$deviceExists) {
    $currentConfig.devices += [PSCustomObject]@{ deviceID = $MainPcDeviceId; name = $MainPcName; addresses = @("dynamic"); introducer = $true }
}

# Folder Logic
$folderIndex = $null
for ($i=0; $i -lt $currentConfig.folders.Count; $i++) {
    if ($currentConfig.folders[$i].id -eq $FolderId) { $folderIndex = $i; break }
}

$sharingDevice = [PSCustomObject]@{ deviceID = $MainPcDeviceId }
if ($folderIndex -ne $null) {
    $currentConfig.folders[$folderIndex].path = $SyncFolderPath
    $isShared = $currentConfig.folders[$folderIndex].devices | Where-Object { $_.deviceID -eq $MainPcDeviceId }
    if (!$isShared) { $currentConfig.folders[$folderIndex].devices += $sharingDevice }
} else {
    $currentConfig.folders += [PSCustomObject]@{ id = $FolderId; label = $FolderId; path = $SyncFolderPath; type = "sendreceive"; devices = @($sharingDevice); fsWatcherEnabled = $true }
}

# Save settings
$jsonPayload = $currentConfig | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$apiUrl/system/config" -Headers $headers -Method Post -Body $jsonPayload -ContentType "application/json"

# ==========================================================
# 5. FINAL START (CRITICAL FIX)
# ==========================================================
Write-Host "`n--- STEP 4: FINAL LAUNCH ---" -ForegroundColor Cyan

# Instead of API restart, we kill it and start it properly
Write-Host "Shutting down temporary instance..."
Stop-Process -Name "syncthing" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

Write-Host "Starting production instance in background..."
# We use --no-console here for a clean background run
$finalArgs = "--no-browser --no-console --home=$configFolder"
Start-Process $realExe -ArgumentList $finalArgs -WindowStyle Hidden

# Add to Windows Registry for Autostart
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $regPath -Name "Syncthing" -Value "$realExe $finalArgs"

# Wait and Verify
Write-Host "Verifying process..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$check = Get-Process -Name "syncthing" -ErrorAction SilentlyContinue

if ($check) {
    Write-Host "SUCCESS: Syncthing is now running and configured!" -ForegroundColor Green
} else {
    Write-Warning "Process not detected. Please check if Proxifier is killing it."
}

Write-Host "`n===================================================" -ForegroundColor Green
Write-Host "DONE! Your VM is ready."
Write-Host "==================================================="
Start-Sleep -Seconds 2