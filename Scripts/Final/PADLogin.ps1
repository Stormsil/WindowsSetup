Write-Log "Launching PADLogger..." "Green"
Write-Log "  PLEASE DO NOT TOUCH MOUSE OR KEYBOARD! " "Red"

$botExe = Join-Path $Global:SetupDir "TOOL_PADLogger.exe"
if (Test-Path $botExe) {
    try {
        $proc = Start-Process -FilePath $botExe -WorkingDirectory $Global:SetupDir -PassThru
        if ($proc.Id) {
            Write-Log "Bot launched successfully (PID: $($proc.Id))." "Green"
        }
        else {
            Write-Log "Failed to launch Bot process." "Red"
        }
    }
    catch {
        Write-Log "Critical error launching PADLogger: $_" "Red"
    }
}
else {
    Write-Log "ERROR: PADLogger.exe not found in $Global:SetupDir" "Red"
}
