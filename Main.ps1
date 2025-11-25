# ==========================================
# MAIN CLOUD SETUP (LOGIC CORE)
# ==========================================
# This script acts as the "Brain". It installs everything.
# Network is assumed to be configured by Start.ps1.

# --- CONFIGURATION ---
$GithubUser = "Stormsil"
$RepoName   = "WindowsSetup"
$ReleaseTag = "files" 
$SetupDir   = "C:\WindowsSetup"

# ==========================================
# -1. INIT
# ==========================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Log { 
    param([string]$Msg, [string]$Color="White") 
    Write-Host "[MAIN] $((Get-Date).ToString('HH:mm:ss')) $Msg" -ForegroundColor $Color 
}

Write-Log "=== MAIN SETUP LOGIC STARTED ===" "Cyan"

# Create setup directory
if (-not (Test-Path $SetupDir)) { New-Item -Path $SetupDir -ItemType Directory -Force | Out-Null }

# ==========================================
# 0. DYNAMIC DOWNLOAD & UNZIP (API MODE)
# ==========================================
Write-Log "Connecting to GitHub API to fetch file list..." "Cyan"

if (-not (Test-Path $SetupDir)) { New-Item -Path $SetupDir -ItemType Directory -Force | Out-Null }

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ApiUrl = "https://api.github.com/repos/$GithubUser/$RepoName/releases/tags/$ReleaseTag"
    
    $ReleaseData = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing
    
    if ($ReleaseData.assets.Count -gt 0) {
        Write-Log "Found $($ReleaseData.assets.Count) files in release. Starting download..." "Green"
        
        foreach ($asset in $ReleaseData.assets) {
            $FileName  = $asset.name
            $DownloadUrl = $asset.browser_download_url
            $LocalPath = Join-Path $SetupDir $FileName
            
            if ($FileName -match "Source code") { continue }

            if (-not (Test-Path $LocalPath) -or (Get-Item $LocalPath).Length -eq 0) {
                Write-Log "Downloading: $FileName..." "Yellow"
                try {
                    Invoke-WebRequest -Uri $DownloadUrl -OutFile $LocalPath -UseBasicParsing
                    Write-Log "  -> Saved." "Gray"
                } catch {
                    Write-Log "  -> Failed to download $FileName : $_" "Red"
                    continue
                }
            } else {
                Write-Log "Skipping $FileName (Already exists)." "Gray"
            }

            if ($LocalPath.EndsWith(".zip")) {
                Write-Log "  -> Archive detected. Extracting..." "Cyan"
                try {
                    Expand-Archive -Path $LocalPath -DestinationPath $SetupDir -Force
                    
                    Remove-Item $LocalPath -Force
                    Write-Log "  -> Extracted and ZIP deleted." "Green"
                } catch {
                    Write-Log "  -> Extraction failed: $_" "Red"
                }
            }
        }
    } else {
        Write-Log "WARNING: No assets found in this release tag!" "Red"
    }

} catch {
    Write-Log "API ERROR: Could not fetch release info. Check User/Repo/Tag." "Red"
    Write-Log "Details: $_" "Red"
}

# ==========================================
# 1. INSTALL VCREDIST (BATCH)
# ==========================================
# Запускаем install_all.bat, который вылетел из vcredist.zip
$vcredistBat = "$SetupDir\vcredist\install_all.bat"

if (Test-Path $vcredistBat) {
    Write-Log "Installing VCRedist (AIO)..." "Cyan"
    try {
        # -Verb RunAs запускает от имени админа (хотя скрипт и так админ, но на всякий случай)
        Start-Process -FilePath $vcredistBat -Verb RunAs -Wait
        Write-Log "  -> VCRedist installation complete." "Green"
    } catch {
        Write-Log "  -> Error running install_all.bat: $_" "Red"
    }
} else {
    Write-Log "WARNING: vcredist\install_all.bat not found. Skipping." "Yellow"
}

# ==========================================
# 1. POWER SETTINGS
# ==========================================
Write-Log "Applying High Performance power settings..." "Gray"
try {
    powercfg -setactive SCHEME_MIN
    powercfg /change monitor-timeout-ac 0
    powercfg /change monitor-timeout-dc 0
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
} catch {
    Write-Log "Error setting power scheme: $_" "Red"
}

# ==========================================
# 2. ENVIRONMENT & CONSOLE TWEAKS
# ==========================================
Write-Log "Configuring environment variables..." "Gray"
[Environment]::SetEnvironmentVariable("OPENCV_SKIP_CPU_BASELINE_CHECK", "1", "User")

$consolePath = "HKCU:\Console"
if (-not (Test-Path $consolePath)) { New-Item $consolePath -Force | Out-Null }
New-ItemProperty -Path $consolePath -Name "WindowSize" -Value 0x001E005A -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $consolePath -Name "WindowPosition" -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $consolePath -Name "ScreenBufferSize" -Value 0x2328005A -PropertyType DWord -Force | Out-Null

# ==========================================
# 3. AUTO-LOGIN SETUP
# ==========================================
Write-Log "Setting up Auto-Login (User: Alex)..." "Gray"
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$devicePath   = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"

if (-not (Test-Path $devicePath)) { New-Item $devicePath -Force | Out-Null }
New-ItemProperty -Path $devicePath   -Name "DevicePasswordLessBuildVersion" -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Value "Alex" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Value "1204" -PropertyType String -Force | Out-Null

# ==========================================
# 4. DISABLE NETWORK WIZARD
# ==========================================
Write-Log "Disabling Network Location Wizard..." "Gray"
$netPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff"
if (-not (Test-Path $netPath)) { New-Item $netPath -Force | Out-Null }
New-ItemProperty -Path $netPath -Name "Default" -Value "" -PropertyType String -Force | Out-Null

# ==========================================
# 5. SYSTEM HARDENING
# ==========================================
Write-Log "`n=== SYSTEM HARDENING ===" "Cyan"

# --- 5a. WINDOWS UPDATE BLOCKER (WUB) ---
# We expect Wub_x64.exe to be present in C:\WindowsSetup
$wubExe = Join-Path $SetupDir "Wub_x64.exe"

if (Test-Path $wubExe) {
    Write-Log "Executing WUB (Disable Updates)..." "Yellow"
    try {
        $proc = Start-Process -FilePath $wubExe -ArgumentList "/D", "/P" -Wait -PassThru
        Write-Log "  -> Updates Disabled & Protected." "Green"
    } catch {
        Write-Log "  -> Error running WUB: $_" "Red"
    }
} else {
    Write-Log "  -> WARNING: Wub_x64.exe not found locally." "Red"
}

# --- 5b. DEBLOAT (Raphire) ---
Write-Log "Running Debloat (Raphire)..." "Yellow"
$debloatScript = "$env:TEMP\Win11Debloat.ps1"
$debloatUrl = "https://raw.githubusercontent.com/Raphire/Win11Debloat/master/Win11Debloat.ps1"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $debloatUrl -OutFile $debloatScript -UseBasicParsing
    
    if (Test-Path $debloatScript) {
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass", "-File `"$debloatScript`"", "-Silent", "-RemoveApps", "-DisableTelemetry", "-DisableBing", "-DisableGaming" -Wait
        Write-Log "  -> Telemetry disabled & Apps removed." "Green"
        Remove-Item $debloatScript -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Log "  -> Debloat Error: $_" "Red"
}

# --- 5c. ACTIVATION (MAS - NEW LINK) ---
Write-Log "Activating Windows (MAS HWID)..." "Yellow"

try {
    # OFFICIAL MAS COMMAND (Silent Mode via ScriptBlock)
    # This downloads the script from get.activated.win and passes /hwid argument
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    Write-Log "  -> Connecting to get.activated.win..." "Gray"
    
    & ([ScriptBlock]::Create((irm https://get.activated.win))) /hwid | Out-Null
    
    Write-Log "  -> Activation sequence executed." "Green"
    Write-Log "  -> Check Settings > Activation to confirm." "Gray"

} catch {
    Write-Log "  -> Activation Failed: $_" "Red"
    Write-Log "  -> Please check Internet connectivity or DNS." "Red"
}

# ==========================================
# 6. PROFILE & SCHEDULER
# ==========================================
Write-Log "Setting Network Profile to Public..." "Gray"
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Public -ErrorAction SilentlyContinue

$taskName = "AutoSetAllNetworksToPublic"
$taskCmd  = "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Public -ErrorAction SilentlyContinue"
$taskAct  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -Command `"$taskCmd`""
$taskTrig = New-ScheduledTaskTrigger -AtStartup
$taskPrin = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $taskName -Action $taskAct -Trigger $taskTrig -Principal $taskPrin -Force | Out-Null
    Write-Log "Scheduled task created." "Green"
} catch {}

# ==========================================
# 7. INSTALL CHOCOLATEY
# ==========================================
Write-Log "`n=== Software Installation ===" "Cyan"

if (-not (Get-Command "choco" -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Chocolatey..." "Yellow"
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    } catch { Write-Log "Choco Install Error: $_" "Red" }
}

# ==========================================
# 8. INSTALL LOCAL DRIVERS (DOWNLOADED BY LOADER)
# ==========================================
Write-Log "Installing Local Drivers..." "Yellow"

# 8a. Trust Certificate (Tether)
$tetherPath = Join-Path $SetupDir "TetherDriver.exe"
if (Test-Path $tetherPath) {
    try {
        $sig = Get-AuthenticodeSignature -FilePath $tetherPath
        if ($sig.Status -ne "UnknownError" -and $sig.SignerCertificate) {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "TrustedPublisher", "LocalMachine"
            $store.Open("ReadWrite"); $store.Add($sig.SignerCertificate); $store.Close()
            Write-Log "  -> Tether certificate trusted." "Green"
        }
    } catch {}
}

# 8b. Install List
# IMPORTANT: These files must exist in C:\WindowsSetup
# I updated filenames based on your Screenshot (Driver.exe, TSM.exe)
$localInstallers = @(
    @{ Name="Nvidia Driver";   Path=Join-Path $SetupDir "DriverSetup.exe";       Args="-s" },
    @{ Name="Tether Driver";   Path=Join-Path $SetupDir "TetherDriverSetup.exe"; Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" },
    @{ Name="TSM Application"; Path=Join-Path $SetupDir "TSMSetup.exe";          Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" },
    @{ Name="NoMachine";     Path="$SetupDir\NomachineSetup.exe";    Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" },
    @{ Name="Proxifier";     Path="$SetupDir\ProxifierSetup.exe";    Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" },
    @{ Name="Resilio Sync";  Path="$SetupDir\ResilioSetup.exe";      Args="/PERFORMINSTALL /S /NORUN" } 
)

foreach ($app in $localInstallers) {
    if (Test-Path $app.Path) {
        Write-Log "Running $($app.Name)..." "Cyan"
        try {
            $proc = Start-Process -FilePath $app.Path -ArgumentList $app.Args -Wait -PassThru -ErrorAction Stop
            if ($proc.ExitCode -eq 0) { Write-Log "  -> Success." "Green" } 
            else { Write-Log "  -> Finished with code $($proc.ExitCode)." "Gray" }
        } catch { Write-Log "  -> ERROR: $_" "Red" }
    } else {
        Write-Log "Skipping $($app.Name): File not found ($($app.Path))." "Gray"
    }
}

# ==========================================
# 9. INSTALL CHOCO APPS
# ==========================================
# Proxifier removed (moved to local if needed), NoMachine is here
$chocoApps = @(
    "dotnet-8.0-sdk",
    "webview2-runtime",
    "googlechrome",  
    "notepadplusplus",
    "winrar"
)

if (Get-Command "choco" -ErrorAction SilentlyContinue) {
    Write-Log "Installing Choco Packages..." "Yellow"
    choco upgrade $chocoApps -y --no-progress --stop-on-first-failure
}

# ==========================================
# 10. CONFIGURE NOMACHINE
# ==========================================
Write-Log "Configuring NoMachine..." "Yellow"
$nodeCfgPath = "C:\Program Files\NoMachine\etc\node.cfg"

if (Test-Path $nodeCfgPath) {
    try {
        $content = Get-Content $nodeCfgPath
        $settings = @{
            "ShowDesktopViewed"             = "0"
            "EnableSoundAlert"              = "0"
            "EnableHardwareAcceleration"    = "0"
            "EnableHardwareEncoding"        = "0"
            "DisplayServerUseVideoFrameRate"= "0"
            "EnableDisplayServerVideoCodec" = "0"
        }
        $newContent = @()
        $modified = $false
        
        foreach ($line in $content) {
            $newLine = $line
            foreach ($key in $settings.Keys) {
                if ($line -match "^\s*#?\s*$key\s+\d+") {
                    $newValue = "$key $($settings[$key])"
                    if ($line -ne $newValue) { $newLine = $newValue; $modified = $true }
                }
            }
            $newContent += $newLine
        }
        
        if ($modified) {
            Stop-Service "nxserver" -Force -ErrorAction SilentlyContinue
            Set-Content -Path $nodeCfgPath -Value $newContent
            Start-Service "nxserver" -ErrorAction SilentlyContinue
            Write-Log "  -> Config updated." "Green"
        }
    } catch { Write-Log "  -> Config Error: $_" "Red" }
}

# ==========================================
# 11. INSTALL POWER AUTOMATE (BITS)
# ==========================================
Write-Log "Installing Power Automate..." "Yellow"
$padUrl = "https://go.microsoft.com/fwlink/?linkid=2102613"
$padInstaller = "$env:TEMP\PADSetup.exe"

try {
    Import-Module BitsTransfer -ErrorAction SilentlyContinue
    Start-BitsTransfer -Source $padUrl -Destination $padInstaller -Priority Foreground
    Start-Process -FilePath $padInstaller -ArgumentList "-Silent", "-Install", "-ACCEPTEULA" -PassThru -Wait
    Remove-Item -Path $padInstaller -Force -ErrorAction SilentlyContinue
    Write-Log "  -> Installed." "Green"
} catch {
    Write-Log "  -> PAD Install Error: $_" "Red"
}

# ==========================================
# 12. START BOT (PADLogger)
# ==========================================
Write-Log "`n=== Starting Auto-Login Bot ===" "Cyan"

$botExe    = Join-Path $PSScriptRoot "PADLogger.exe"
$botConfig = Join-Path $PSScriptRoot "config.json"

if ((Test-Path $botExe) -and (Test-Path $botConfig)) {
    Write-Log "Launching PADLogger..." "Green"
    Write-Log "  PLEASE DO NOT TOUCH MOUSE OR KEYBOARD! " "Red"
    try {
        Start-Process -FilePath $botExe -WorkingDirectory $PSScriptRoot -PassThru -Wait
        Write-Log "Bot finished." "Green"
    } catch {
        Write-Log "Bot Crash: $_" "Red"
    }
} else {
    Write-Log "ERROR: PADLogger.exe or config.json missing in $PSScriptRoot" "Red"
}

# ==========================================
# 13. COMPLETION
# ==========================================
Write-Log "`n=== SETUP COMPLETE ===" "Green"
Write-Log "Closing automatically in 5 seconds..." "Gray"
Start-Sleep -Seconds 5