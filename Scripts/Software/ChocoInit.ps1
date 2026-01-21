if (-not (Get-Command "choco" -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Chocolatey..." "Yellow"
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        
        # Increased resilience for 503 errors (30 attempts * 30s = ~15 mins max wait)
        Invoke-Retry -MaxAttempts 30 -DelaySeconds 30 -Action {
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) | Out-Null
        }
        
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Verify Install
        if (Get-Command "choco" -ErrorAction SilentlyContinue) {
             Write-Log "Chocolatey installed successfully." "Green"
        } else {
             throw "Chocolatey command not found after installation."
        }
    }
    catch { Write-Log "Choco Install Error: $_" "Red" }
}
