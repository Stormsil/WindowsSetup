function Install-Program {
    param(
        [string]$Name,
        [string]$File,
        [string]$InstallArgs
    )

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

Export-ModuleMember -Function Install-Program, Invoke-Retry