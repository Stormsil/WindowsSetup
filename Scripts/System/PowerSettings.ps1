Write-Log "Applying High Performance power settings..." "Gray"
try {
    powercfg -setactive SCHEME_MIN
    powercfg /change monitor-timeout-ac 0
    powercfg /change monitor-timeout-dc 0
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
}
catch {
    Write-Log "Error setting power scheme: $_" "Red"
}
