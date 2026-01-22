# ==========================================
# AFTER RESTART ORCHESTRATOR
# ==========================================
# This script runs once after the system reboots.
# It handles the sequence: SyncThing -> Wait -> Proxifier

$ScriptDir = $PSScriptRoot

# Function to run a script and wait (or not)
function Invoke-Step {
    param($ScriptFile, $Wait = $true)
    $Path = Join-Path $ScriptDir $ScriptFile
    if (Test-Path $Path) {
        Write-Host "Starting: $ScriptFile" -ForegroundColor Cyan
        if ($Wait) {
            # Run inside this window
            & $Path
        } else {
            # Start and forget (if needed)
            Start-Process powershell.exe -ArgumentList "-NoExit", "-File `"$Path`""
        }
    } else {
        Write-Host "Script not found: $Path" -ForegroundColor Red
    }
}

Write-Host "--- POST-REBOOT SETUP STARTED ---" -ForegroundColor Green

# 1. Wait 45 Seconds as requested (Allow system/services to stabilize)
Write-Host "Waiting 45 seconds for system load..." -ForegroundColor Yellow
Start-Sleep -Seconds 45

# 2. SyncThing
Invoke-Step "SyncThingSetup.ps1" -Wait $true

# 3. Proxifier
Invoke-Step "ProxifierSetup.ps1" -Wait $true

Write-Host "--- POST-REBOOT SETUP COMPLETE ---" -ForegroundColor Green
Start-Sleep -Seconds 5
