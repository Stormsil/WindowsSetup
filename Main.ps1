# ==============================================================================
# MAIN ORCHESTRATOR (FULL & PRIVATE REPO COMPATIBLE)
# ==============================================================================
# AUTHOR: Stormsil
# REPO: WindowsSetup
# VERSION: 3.1 (Full logic restored + Private Repo Patch)
# ==============================================================================

# 1. ПРИНИМАЕМ ТОКЕН ОТ BOOTSTRAPPER (Это единственное изменение в шапке)
param(
    [string]$Token = ""
)

# --- CONFIGURATION ---
$GithubUser = "Stormsil"
$RepoName   = "WindowsSetup"
$ReleaseTag = "files"
# ВАЖНО: Так как Bootstrapper запускает нас из папки System, используем текущий путь
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
    Write-Log "WARNING: No GitHub Token provided! Downloads from Private Repo will fail." "Red"
}

# Ensure setup directory exists (хотя мы уже в нем)
if (-not (Test-Path $SetupDir)) { New-Item -Path $SetupDir -ItemType Directory -Force | Out-Null }

# ==========================================
# 0. DYNAMIC DOWNLOAD (WEBCLIENT - PRIVATE ACCESS)
# ==========================================
Write-Log "Connecting to GitHub API..." "Cyan"

try {
    # Для приватного репо нужны заголовки
    $Headers = @{
        "Authorization" = "token $Token"
        "User-Agent"    = "PowerShell-Setup"
    }
    
    $ApiUrl = "https://api.github.com/repos/$GithubUser/$RepoName/releases/tags/$ReleaseTag"
    
    # Получаем список файлов
    $ReleaseData = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -UseBasicParsing
    
    if ($ReleaseData.assets.Count -gt 0) {
        Write-Log "Found $($ReleaseData.assets.Count) files. Starting High-Speed Download..." "Green"
        
        # Создаем быстрый WebClient (аналог BITS по скорости, но работает с токенами)
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("Authorization", "token $Token")
        $wc.Headers.Add("User-Agent", "PowerShell-Setup")
        $wc.Headers.Add("Accept", "application/octet-stream") # Магия для скачивания бинарников
        
        foreach ($asset in $ReleaseData.assets) {
            $FileName    = $asset.name
            # В приватных репо используем 'url', а не 'browser_download_url'
            $DownloadUrl = $asset.url 
            $LocalPath   = Join-Path $SetupDir $FileName
            
            if ($FileName -match "Source code") { continue }

            if (-not (Test-Path $LocalPath) -or (Get-Item $LocalPath).Length -eq 0) {
                Write-Log "Downloading: $FileName..." "Yellow"
                
                try {
                    $wc.DownloadFile($DownloadUrl, $LocalPath)
                    Write-Log "  -> Complete." "Gray"
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
                    Remove-Item $LocalPath -Force 
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
    Write-Log "API ERROR: Could not fetch release info. Check Token/User/Repo." "Red"
    Write-Log "Details: $_" "Red"
}

# ==========================================
# 1. INSTALL VCREDIST (BATCH)
# ==========================================
$vcredistBat = Join-Path $SetupDir "vcredist\install_all.bat"

if (Test-Path $vcredistBat) {
    Write-Log "Installing VCRedist (AIO)..." "Cyan"
    try {
        Start-Process -FilePath $vcredistBat -Verb RunAs -Wait
        Write-Log "  -> VCRedist installation complete." "Green"
    } catch {
        Write-Log "  -> Error running install_all.bat: $_" "Red"
    }
} else {
    Write-Log "WARNING: vcredist\install_all.bat not found. Skipping." "Yellow"
}

# ==========================================
# 2. POWER SETTINGS
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
# 3. ENVIRONMENT & CONSOLE TWEAKS
# ==========================================
Write-Log "Configuring environment variables..." "Gray"
[Environment]::SetEnvironmentVariable("OPENCV_SKIP_CPU_BASELINE_CHECK", "1", "User")

$consolePath = "HKCU:\Console"
if (-not (Test-Path $consolePath)) { New-Item $consolePath -Force | Out-Null }
New-ItemProperty -Path $consolePath -Name "WindowSize" -Value 0x001E005A -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $consolePath -Name "WindowPosition" -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $consolePath -Name "ScreenBufferSize" -Value 0x2328005A -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $consolePath -Name "QuickEdit" -Value 0 -PropertyType DWord -Force | Out-Null

# ==========================================
# 4. AUTO-LOGIN SETUP
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
# 5. DISABLE NETWORK WIZARD
# ==========================================
Write-Log "Disabling Network Location Wizard..." "Gray"
$netPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff"
if (-not (Test-Path $netPath)) { New-Item $netPath -Force | Out-Null }
New-ItemProperty -Path $netPath -Name "Default" -Value "" -PropertyType String -Force | Out-Null

# ==========================================
# 6. SYSTEM HARDENING
# ==========================================
Write-Log "`n=== SYSTEM HARDENING ===" "Cyan"

# --- 6a. WINDOWS UPDATE BLOCKER (WUB) ---
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
# 7. PROFILE & SCHEDULER
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
# 8. INSTALL CHOCOLATEY
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
# 9. INSTALL LOCAL DRIVERS (DOWNLOADED BY LOADER)
# ==========================================
Write-Log "Installing Local Drivers..." "Yellow"

# 9a. Trust Certificate (Tether)
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

# 9b. Install List
$localInstallers = @(
    @{ Name="Nvidia Driver";   Path="DriverSetup.exe";       Args="-s" },
    @{ Name="Tether Driver";   Path="TetherDriverSetup.exe"; Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" },
    @{ Name="TSM Application"; Path="TSMSetup.exe";          Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" },
    @{ Name="NoMachine";       Path="NomachineSetup.exe";    Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" },
    @{ Name="Proxifier";       Path="ProxifierSetup.exe";    Args="/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" },
    @{ Name="Resilio Sync";    Path="ResilioSetup.exe";      Args="/PERFORMINSTALL /S /NORUN" } 
)

foreach ($app in $localInstallers) {
    $FullPath = Join-Path $SetupDir $app.Path
    if (Test-Path $FullPath) {
        Write-Log "Running $($app.Name)..." "Cyan"
        try {
            $proc = Start-Process -FilePath $FullPath -ArgumentList $app.Args -Wait -PassThru -ErrorAction Stop
            if ($proc.ExitCode -eq 0) { Write-Log "  -> Success." "Green" } 
            else { Write-Log "  -> Finished with code $($proc.ExitCode)." "Gray" }
        } catch { Write-Log "  -> ERROR: $_" "Red" }
    } else {
        Write-Log "Skipping $($app.Name): File not found." "Gray"
    }
}

# ==========================================
# 10. INSTALL CHOCO APPS
# ==========================================
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
# 11. CONFIGURE NOMACHINE (FULL PARSING)
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
        
        # Полный парсинг как в оригинале
        foreach ($line in $content) {
            $newLine = $line
            foreach ($key in $settings.Keys) {
                # Регулярка для поиска ключа
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
        } else {
            Write-Log "  -> Config already optimal." "Gray"
        }
    } catch { Write-Log "  -> Config Error: $_" "Red" }
}

# ==========================================
# 12. INSTALL POWER AUTOMATE
# ==========================================
Write-Log "Installing Power Automate..." "Yellow"
$padUrl = "https://go.microsoft.com/fwlink/?linkid=2102613"
$padInstaller = "$env:TEMP\PADSetup.exe"

try {
    # Using WebClient instead of BITS for simplicity in Main
    (New-Object System.Net.WebClient).DownloadFile($padUrl, $padInstaller)
    Start-Process -FilePath $padInstaller -ArgumentList "-Silent", "-Install", "-ACCEPTEULA" -PassThru -Wait
    Remove-Item -Path $padInstaller -Force -ErrorAction SilentlyContinue
    Write-Log "  -> Installed." "Green"
} catch {
    Write-Log "  -> PAD Install Error: $_" "Red"
}

# ==========================================
# 13. START BOT (PADLogger)
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
# 14. COMPLETION
# ==========================================
Write-Log "`n=== SETUP COMPLETE ===" "Green"
Write-Log "Closing automatically in 5 seconds..." "Gray"
Start-Sleep -Seconds 5