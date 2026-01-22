# ==========================================
# AFTER RESTART ORCHESTRATOR
# ==========================================
# This script runs once after the system reboots.
# It handles the sequence: AutoLogin -> Wait -> SyncThing -> Proxifier

$ScriptDir = $PSScriptRoot
# Calculate Root Directory (Scripts/AfterRestart -> Scripts -> Root)
$Global:SetupDir = Resolve-Path (Join-Path $ScriptDir "..\..")

# Import Modules to support AutoLogin (needs Get-SetupConfig, Write-Log)
Import-Module (Join-Path $Global:SetupDir "Modules\Logger.psm1") -Force
Import-Module (Join-Path $Global:SetupDir "Modules\Utils.psm1") -Force

# Function to run a script and wait (or not)
function Invoke-Step {
    param($ScriptFile, $Wait = $true)
    
    # Try current dir first, then System dir (for AutoLogin)
    $Path = Join-Path $ScriptDir $ScriptFile
    if (-not (Test-Path $Path)) {
        # Fallback for cross-phase scripts
        $Path = Join-Path $Global:SetupDir "Scripts\System\$ScriptFile"
    }

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

# 0. Re-Run AutoLogin (Ensure it sticks)
Invoke-Step "AutoLogin.ps1" -Wait $true

# 1. Wait 45 Seconds as requested (Allow system/services to stabilize)
Write-Host "Waiting 45 seconds for system load..." -ForegroundColor Yellow
Start-Sleep -Seconds 45

# 2. SyncThing
Invoke-Step "SyncThingSetup.ps1" -Wait $true

# 3. Proxifier
Invoke-Step "ProxifierSetup.ps1" -Wait $true

Write-Host "--- POST-REBOOT SETUP COMPLETE ---" -ForegroundColor Green
Start-Sleep -Seconds 5
