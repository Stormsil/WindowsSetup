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

    # 3. Resolve Full Path to Installer (Look in Root -> GitReleaseDownloaded -> Local)
    $FullInstallerPath = Join-Path $Global:SetupDir $File
    if (-not (Test-Path $FullInstallerPath)) {
        # Check GitReleaseDownloaded folder
        $DownloadPath = Join-Path $Global:SetupDir "GitReleaseDownloaded\$File"
        if (Test-Path $DownloadPath) {
            $FullInstallerPath = $DownloadPath
        } else {
            # Fallback to local if not found anywhere
            $FullInstallerPath = $File
        }
    }

    if (Test-Path $FullInstallerPath) {
        Write-Log "Installing $Name ($FullInstallerPath)..." "Cyan"
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
    
    if (-not (Test-Path $FullPath)) {
        $DownloadPath = Join-Path $Global:SetupDir "GitReleaseDownloaded\$File"
        if (Test-Path $DownloadPath) { $FullPath = $DownloadPath }
    }

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
    
    if (-not (Test-Path $FullPath)) {
        $DownloadPath = Join-Path $Global:SetupDir "GitReleaseDownloaded\$CertFile"
        if (Test-Path $DownloadPath) { 
            $FullPath = $DownloadPath 
        } else {
            Write-Log "Certificate/File not found: $FullPath" "Red"
            return
        }
    }

    if ($CertFile.EndsWith(".exe")) {
        Write-Log "Extracting certificate from EXE: $CertFile" "Gray"
        try {
            $Signature = Get-AuthenticodeSignature -FilePath $FullPath
            if ($Signature.Status -eq 'Valid' -or $Signature.Status -eq 'Untrusted') {
                $Cert = $Signature.SignerCertificate
                if ($Cert) {
                    $Store = [System.Security.Cryptography.X509Certificates.X509Store]::new("TrustedPublisher", "LocalMachine")
                    $Store.Open("ReadWrite")
                    $Store.Add($Cert)
                    $Store.Close()
                    Write-Log "  -> Certificate added to TrustedPublisher." "Green"
                } else {
                    Write-Log "  -> No SignerCertificate found in signature." "Yellow"
                }
            } else {
                Write-Log "  -> EXE Signature Status: $($Signature.Status)" "Yellow"
            }
        } catch {
            Write-Log "  -> Failed to import cert from EXE: $_" "Red"
        }
    } else {
        # Default behavior for .cer/.crt
        Write-Log "Importing Certificate: $CertFile" "Gray"
        try {
            Import-Certificate -FilePath $FullPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
            Write-Log "  -> Success." "Green"
        } catch {
             Write-Log "  -> Failed to import cert: $_" "Red"
        }
    }
}

function Get-VmName {
    try {
        $OemStrings = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty OEMStringArray
        $targetIp = $OemStrings | Where-Object { $_ -match "^192\.168\.\d{1,3}\.\d{1,3}$" } | Select-Object -First 1
        if ($targetIp) {
            # Извлекаем последнюю цифру IP для определения номера VM
            $lastOctet = $targetIp.Split('.')[-1]
            # Если IP 192.168.112.31 -> последняя цифра 31, берем первую цифру (3) как номер vmbr
            $vmNum = $lastOctet.Substring(0, 1) 
            return "wow$vmNum"
        }
    } catch {}
    return "unknown-vm"
}

Export-ModuleMember -Function Get-SetupConfig, Install-Program, Get-InstalledApp, Invoke-Retry, Invoke-BatchFile, Add-TrustedCertificate, Get-VmName
