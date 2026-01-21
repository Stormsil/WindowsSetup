# ==========================================
# WINDOWS ACTIVATION (Offline MAS - HWID)
# ==========================================
# Uses local MAS_AIO.cmd provided in the Scripts folder.

Write-Log "Checking Activation Status..." "Cyan"

# 1. Check if already permanently activated
$License = Get-CimInstance SoftwareLicensingProduct | Where-Object { $_.PartialProductKey -and $_.Name -like "Windows*" } | Select-Object -First 1
if ($License.LicenseStatus -eq 1) {
    Write-Log "Windows is already activated." "Green"
    return
}

Write-Log "Starting Windows Activation (Offline HWID)..." "Cyan"

# Locate the MAS file (It is in Scripts/Tools/)
$MasFile = Join-Path $Global:SetupDir "Scripts\Tools\MAS_AIO.cmd"

if (Test-Path $MasFile) {
    try {
        Write-Log "Launching MAS_AIO.cmd..." "Gray"
        
        # We use a trick: echo 1 | script to auto-select option 1 if HWID flag fails for some reason, 
        # but MAS_AIO /HWID should be silent. We add 'start /b' or just call it directly.
        $cmdArgs = "/c `"$MasFile`" /HWID"
        $proc = Start-Process "cmd.exe" -ArgumentList $cmdArgs -Verb RunAs -PassThru -Wait -NoNewWindow
        
        if ($proc.ExitCode -eq 0) {
            Write-Log "Activation script executed." "Green"
        } else {
            Write-Log "Activation script exited with code $($proc.ExitCode)." "Yellow"
        }
        
    } catch {
        Write-Log "Error executing MAS: $_" "Red"
    }
} else {
    Write-Log "ERROR: Offline activation file not found at: $MasFile" "Red"
}