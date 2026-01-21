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
        
        # Launch CMD with /HWID argument for unattended activation
        # Note: MAS AIO usually supports command line args if they are passed correctly.
        # Standard offline MAS usage for HWID is often interactive, but let's try passing the arg.
        # If the cmd doesn't support args directly, we might need a small wrapper, but usually it works or we rely on the script logic.
        # According to documentation: MAS_AIO.cmd /HWID is supported.
        
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$MasFile`" /HWID" -Verb RunAs -PassThru -Wait -WindowStyle Hidden
        
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