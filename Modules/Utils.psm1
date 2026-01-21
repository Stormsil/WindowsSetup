# ==========================================
# UTILS MODULE
# ==========================================

function Get-SetupConfig {
    $ConfigPath = Join-Path $Global:SetupDir "setup_config.json"
    if (Test-Path $ConfigPath) {
        try {
            return Get-Content $ConfigPath -Raw | ConvertFrom-Json
        } catch {
            Write-Log "ERROR: Failed to parse setup_config.json: $_" "Red"
            return $null
        }
    }
    return $null
}

function Install-Program {
    param(
        [string]$Name,
        [string]$File,
        [string]$InstallArgs,
        [string]$CheckPath = "",
        [string]$CheckRegistry = ""
    )

    # 1. Registry Check
    if ($CheckRegistry -and (Get-InstalledApp -NamePattern $CheckRegistry)) {
        Write-Log "Skipping $Name (Detected in Registry: $CheckRegistry)." "Green"
        return
    }

    # 2. Path Check
    if ($CheckPath -and (Test-Path $CheckPath)) {
        Write-Log "Skipping $Name (Already Installed at $CheckPath)." "Green"
        return
    }

    # 3. Resolve Full Path to Installer (Ensure we look in the main SetupDir)
    $FullInstallerPath = Join-Path $Global:SetupDir $File
    if (-not (Test-Path $FullInstallerPath)) {
        # Fallback to local if not found in root
        $FullInstallerPath = $File
    }

    if (Test-Path $FullInstallerPath) {
        Write-Log "Installing $Name..." "Cyan"
        try {
            $Proc = Start-Process -FilePath $FullInstallerPath -ArgumentList $InstallArgs -PassThru -Wait -NoNewWindow
            if ($Proc.ExitCode -eq 0 -or $Proc.ExitCode -eq 3010) {
                Write-Log "  -> Success." "Green"
            } else {
                Write-Log "  -> Failed (Exit Code: $($Proc.ExitCode))." "Red"
            }
        } catch {
            Write-Log "  -> Execution Failed: $_" "Red"
        }
    } else {
        Write-Log "Installer for $Name not found ($FullInstallerPath)." "Yellow"
    }
}

function Get-InstalledApp {
    param([string]$NamePattern)
    $UninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($Path in $UninstallPaths) {
        $Results = Get-ItemProperty $Path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$NamePattern*" }
        if ($Results) { return $Results }
    }
    return $null
}

function Invoke-Retry {
    param ([ScriptBlock]$Action, [int]$MaxAttempts = 3, [int]$DelaySeconds = 2)
    $Attempt = 0
    while ($Attempt -lt $MaxAttempts) {
        $Attempt++
        try { return & $Action } catch {
            Write-Log "Attempt $Attempt/$MaxAttempts failed: $_" "Yellow"
            if ($Attempt -lt $MaxAttempts) { Start-Sleep -Seconds $DelaySeconds } else { throw $_ }
        }
    }
}

function Invoke-BatchFile {
    param([string]$File)
    $FullPath = Join-Path $Global:SetupDir $File
    if (Test-Path $FullPath) {
        Write-Log "Executing Batch: $File" "Gray"
        Start-Process "cmd.exe" -ArgumentList "/c `"$FullPath`"" -Wait -NoNewWindow
    } else {
        Write-Log "Batch file not found: $FullPath" "Red"
    }
}

function Add-TrustedCertificate {
    param([string]$CertFile)
    $FullPath = Join-Path $Global:SetupDir $CertFile
    if (Test-Path $FullPath) {
        Write-Log "Importing Certificate: $CertFile" "Gray"
        Import-Certificate -FilePath $FullPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    } else {
        Write-Log "Certificate not found: $FullPath" "Red"
    }
}

Export-ModuleMember -Function Get-SetupConfig, Install-Program, Get-InstalledApp, Invoke-Retry, Invoke-BatchFile, Add-TrustedCertificate
