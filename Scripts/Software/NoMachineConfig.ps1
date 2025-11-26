Write-Log "Configuring NoMachine..." "Yellow"
$nodeCfgPath = "C:\Program Files\NoMachine\etc\node.cfg"

if (Test-Path $nodeCfgPath) {
    try {
        $content = Get-Content $nodeCfgPath
        $settings = @{
            "ShowDesktopViewed"              = "0"
            "EnableSoundAlert"               = "0"
            "EnableHardwareAcceleration"     = "0"
            "EnableHardwareEncoding"         = "0"
            "DisplayServerUseVideoFrameRate" = "0"
            "EnableDisplayServerVideoCodec"  = "0"
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
    }
    catch { Write-Log "  -> Config Error: $_" "Red" }
}
