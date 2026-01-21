function Install-Program {
    param(
        [string]$Name,
        [string]$File,
        [string]$InstallArgs,
        [string]$CheckPath = "",
        [string]$CheckRegistry = ""
    )

    # 1. Declarative Check (Registry)
    if ($CheckRegistry) {
        if (Get-InstalledApp -NamePattern $CheckRegistry) {
            Write-Log "Skipping $Name (Detected in Registry: $CheckRegistry)." "Green"
            return
        }
    }

    # 2. Declarative Check (File Path)
    if ($CheckPath -and (Test-Path $CheckPath)) {
        Write-Log "Skipping $Name (Already Installed at $CheckPath)." "Green"
        return
    }

    # 3. Proceed with Install
    if (Test-Path $File) {
        Write-Log "Installing $Name..." "Cyan"
        try {
            $Proc = Start-Process -FilePath $File -ArgumentList $InstallArgs -PassThru -Wait -NoNewWindow
            
            if ($Proc.ExitCode -eq 0) {
                Write-Log "  -> Success." "Green"
            } elseif ($Proc.ExitCode -eq 3010) {
                Write-Log "  -> Success (Reboot Required)." "Yellow"
            } else {
                Write-Log "  -> Failed (Exit Code: $($Proc.ExitCode))." "Red"
            }
            
            # 3. Post-Install Verification
            if ($CheckPath) {
                if (Test-Path $CheckPath) {
                    Write-Log "  -> Verification: File exists." "Green"
                } else {
                     Write-Log "  -> WARNING: Installation finished but target file not found ($CheckPath)." "Yellow"
                }
            }

        } catch {
            Write-Log "  -> Execution Failed: $_" "Red"
        }
    } else {
        Write-Log "Installer for $Name not found ($File)." "Yellow"
    }
}

function Invoke-Retry {
    param (
        [ScriptBlock]$Action,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 2
    )

    $Attempt = 0
    while ($Attempt -lt $MaxAttempts) {
        $Attempt++
        try {
            return & $Action
        } catch {
            Write-Log "Attempt $Attempt/$MaxAttempts failed: $_" "Yellow"
            if ($Attempt -lt $MaxAttempts) { Start-Sleep -Seconds $DelaySeconds }
            else { throw $_ }
        }
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

Export-ModuleMember -Function Install-Program, Invoke-Retry, Get-InstalledApp