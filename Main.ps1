# ==========================================
# MAIN.PS1 - TEST VERSION
# ==========================================
# If you see this running, the Loader successfully 
# downloaded the code from GitHub!

function Write-Log { 
    param([string]$Msg, [string]$Color="White") 
    Write-Host "[CLOUD-LOGIC] $((Get-Date).ToString('HH:mm:ss')) $Msg" -ForegroundColor $Color 
}

Write-Log "========================================" "Cyan"
Write-Log "   CONNECTION SUCCESSFUL!               " "Green"
Write-Log "   I am running from GitHub memory.     " "Green"
Write-Log "========================================" "Cyan"

# 1. ENVIRONMENT CHECK
Write-Log "Checking current environment..." "Yellow"
Write-Log "  -> Computer Name: $env:COMPUTERNAME" "Gray"
Write-Log "  -> Current User:  $env:USERNAME" "Gray"
Write-Log "  -> Working Dir:   $PWD" "Gray"

Start-Sleep -Seconds 1

# 2. SIMULATING WORK
Write-Log "Simulating driver installation (Fake)..." "Yellow"

for ($i = 1; $i -le 5; $i++) {
    Write-Host "." -NoNewline -ForegroundColor Gray
    Start-Sleep -Milliseconds 500
}
Write-Host ""
Write-Log "Fake drivers installed." "Green"

# 3. CREATE PROOF FILE
$ProofFile = "C:\WindowsSetup\test_result.txt"
Write-Log "Creating proof file at: $ProofFile" "Yellow"

try {
    $Date = Get-Date
    $Content = "Success! The loader worked.`nRun time: $Date`nUser: $env:USERNAME"
    Set-Content -Path $ProofFile -Value $Content
    Write-Log "File created successfully." "Green"
} catch {
    Write-Log "Error creating file: $_" "Red"
}

# 4. COMPLETION
Write-Log "========================================" "Cyan"
Write-Log "   TEST COMPLETE. SYSTEM IS READY.      " "Cyan"
Write-Log "========================================" "Cyan"