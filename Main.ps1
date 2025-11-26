# ==========================================
# Главная логика установки Windows
# ==========================================
# This script acts as the "Brain". It installs everything.
# Network is assumed to be configured by Start.ps1.

# 1. ПРИНИМАЕМ ТОКЕН ОТ BOOTSTRAPPER
param(
    [string]$Token = ""
)

# --- CONFIGURATION ---
$GithubUser = "Stormsil"
$RepoName   = "WindowsSetup"
$ReleaseTag = "files" 
# Используем текущую папку скрипта, так как он лежит в System
$SetupDir   = $PSScriptRoot

# ==========================================
# -1. INIT
# ==========================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Log { 
    param([string]$Msg, [string]$Color="White") 
    Write-Host "[MAIN] $((Get-Date).ToString('HH:mm:ss')) $Msg" -ForegroundColor $Color 
}

Write-Log "=== MAIN SETUP LOGIC STARTED ===" "Cyan"

if (-not $Token) {
    Write-Log "WARNING: No GitHub Token provided! Private downloads will fail." "Red"
}

# Create setup directory (if checking separate path)
if (-not (Test-Path $SetupDir)) { New-Item -Path $SetupDir -ItemType Directory -Force | Out-Null }

# ==========================================
# 0. DYNAMIC DOWNLOAD & UNZIP (S3 FIX)
# ==========================================
Write-Log "Connecting to GitHub API..." "Cyan"

try {
    # Заголовки для авторизации в API
    $Headers = @{
        "Authorization" = "token $Token"
        "User-Agent"    = "PowerShell-Setup"
    }

    $ApiUrl = "https://api.github.com/repos/$GithubUser/$RepoName/releases/tags/$ReleaseTag"
    
    # Получаем список файлов
    $ReleaseData = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -UseBasicParsing
    
    if ($ReleaseData.assets.Count -gt 0) {
        Write-Log "Found $($ReleaseData.assets.Count) files. Starting Download..." "Green"
        
        foreach ($asset in $ReleaseData.assets) {
            $FileName = $asset.name
            $ApiAssetUrl = $asset.url # Ссылка API (не прямая)
            $LocalPath = Join-Path $SetupDir $FileName
            
            if ($FileName -match "Source code") { continue }

            if (-not (Test-Path $LocalPath) -or (Get-Item $LocalPath).Length -eq 0) {
                Write-Log "Downloading: $FileName..." "Yellow"
                
                try {
                    # --- S3 REDIRECT FIX START ---
                    # 1. Запрашиваем ссылку у GitHub (с Токеном)
                    $Req = [System.Net.HttpWebRequest]::Create($ApiAssetUrl)
                    $Req.Method = "GET"
                    $Req.Accept = "application/octet-stream"
                    $Req.Headers.Add("Authorization", "token $Token")
                    $Req.UserAgent = "PowerShell-Setup"
                    $Req.AllowAutoRedirect = $false # Важно: не переходим сами
                    
                    try { 
                        $Resp = $Req.GetResponse() 
                    } catch { 
                        $Resp = $_.Exception.Response 
                    }

                    # 2. Получаем реальную ссылку на Amazon S3
                    $RealDownloadUrl = $null
                    if ($Resp.StatusCode -eq [System.Net.HttpStatusCode]::Found -or $Resp.StatusCode -eq [System.Net.HttpStatusCode]::MovedPermanently) {
                        $RealDownloadUrl = $Resp.GetResponseHeader("Location")
                    }
                    $Resp.Close()

                    if ($RealDownloadUrl) {
                        # 3. Качаем "чистым" клиентом без токена
                        $wc = New-Object System.Net.WebClient
                        $wc.DownloadFile($RealDownloadUrl, $LocalPath)
                        Write-Log "  -> Complete." "Gray"
                    } else {
                        Write-Log "  -> Failed to resolve S3 link." "Red"
                    }
                    # --- S3 REDIRECT FIX END ---

                } catch {
                    Write-Log "  -> Download Failed: $_" "Red"
                }
            } else {
                Write-Log "Skipping $FileName (Exists)." "Gray"
            }

            # Авто-Распаковка ZIP
            if ($LocalPath.EndsWith(".zip")) {
                Write-Log "  -> Unzipping archive..." "Cyan"
                try {
                    Expand-Archive -Path $LocalPath -DestinationPath $SetupDir -Force
                    # Remove-Item $LocalPath -Force # Можно раскомментировать для удаления
                    Write-Log "  -> Extracted." "Green"
                } catch {
                    Write-Log "  -> Extraction failed: $_" "Red"
                }
            }
        }
    } else {
        Write-Log "WARNING: No files found in release '$ReleaseTag'!" "Red"
    }

} catch {
    Write-Log "API ERROR: Could not fetch release info. Check User/Repo/Tag." "Red"
    Write-Log "Details: $_" "Red"
}

# ==========================================
# 1. INSTALL VCREDIST (BATCH)
# ==========================================
# Запускаем install_all.bat, который вылетел из vcredist.zip
$vcredistBat = Join-Path $SetupDir "vcredist\install_all.bat"
# Fallback если распаковалось не в папку
if (-not (Test-Path $vcredistBat)) { $vcredistBat = Join-Path $SetupDir "install_all.bat" }

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
$tetherPath = Join-Path $SetupDir "TetherDriverSetup.exe"
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
    @{ Name="NoMachine";     Path=Join-Path $SetupDir "NomachineSetup.exe";    Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" },
    @{ Name="Proxifier";     Path=Join-Path $SetupDir "ProxifierSetup.exe";    Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" },
    @{ Name="Resilio Sync";  Path=Join-Path $SetupDir "ResilioSetup.exe";      Args="/PERFORMINSTALL /S /NORUN" },
    @{ Name="KMS Activator"; Path=Join-Path $SetupDir "KMSAuto++.x64.exe";     Args="/s /gui=no" }
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
# 11. INSTALL POWER AUTOMATE (BITS -> WebClient)
# ==========================================
Write-Log "Installing Power Automate..." "Yellow"
$padUrl = "https://go.microsoft.com/fwlink/?linkid=2102613"
$padInstaller = "$env:TEMP\PADSetup.exe"

try {
    # Using WebClient for simpler handling
    (New-Object System.Net.WebClient).DownloadFile($padUrl, $padInstaller)
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

$botExe    = Join-Path $SetupDir "PADLogger.exe"
$botConfig = Join-Path $SetupDir "config.json"

if ((Test-Path $botExe) -and (Test-Path $botConfig)) {
    Write-Log "Launching PADLogger..." "Green"
    Write-Log "  PLEASE DO NOT TOUCH MOUSE OR KEYBOARD! " "Red"
    
    try {
        # Removed '-Wait' so the script continues immediately
        $proc = Start-Process -FilePath $botExe -WorkingDirectory $SetupDir -PassThru
        
        # Check if process started (has an ID) instead of ExitCode
        if ($proc.Id) {
            Write-Log "Bot launched successfully (PID: $($proc.Id))." "Green"
            Write-Log "Closing setup script..." "Gray"
        } else {
            Write-Log "Failed to launch Bot process." "Red"
        }
    } catch {
        Write-Log "Critical error launching PADLogger: $_" "Red"
    }
} else {
    Write-Log "ERROR: PADLogger.exe or config.json missing in $SetupDir" "Red"
}
# ==========================================
# 13. COMPLETION
# ==========================================
Write-Log "`n=== SETUP COMPLETE ===" "Green"
Write-Log "Closing automatically in 5 seconds..." "Gray"
Start-Sleep -Seconds 5