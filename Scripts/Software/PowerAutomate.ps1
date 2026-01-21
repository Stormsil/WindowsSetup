Write-Log "Installing Power Automate..." "Yellow"
$padUrl = "https://go.microsoft.com/fwlink/?linkid=2102613"
$padInstaller = "$env:TEMP\PADSetup.exe"

try {
    Invoke-Retry -MaxAttempts 3 -DelaySeconds 5 -Action {
        (New-Object System.Net.WebClient).DownloadFile($padUrl, $padInstaller)
    }
    
    Start-Process -FilePath $padInstaller -ArgumentList "-Silent", "-Install", "-ACCEPTEULA" -PassThru -Wait
    Remove-Item -Path $padInstaller -Force -ErrorAction SilentlyContinue
    Write-Log "  -> Installed." "Green"
}
catch {
    Write-Log "  -> PAD Install Error: $_" "Red"
}
