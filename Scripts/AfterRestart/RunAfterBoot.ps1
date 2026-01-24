# ==========================================
# AFTER RESTART ORCHESTRATOR
# ==========================================
# This script runs post-reboot tasks with strict ordering and idempotency.

$ScriptDir = $PSScriptRoot
# Calculate Root Directory (Scripts/AfterRestart -> Scripts -> Root)
$Global:SetupDir = Resolve-Path (Join-Path $ScriptDir "..\..")

# Import Modules
Import-Module (Join-Path $Global:SetupDir "Modules\Logger.psm1") -Force
Import-Module (Join-Path $Global:SetupDir "Modules\Utils.psm1") -Force
Import-Module (Join-Path $Global:SetupDir "Modules\StateManager.psm1") -Force

Write-Header "POST-REBOOT SETUP STARTED"
Write-Log "State File: $(Get-StateFilePath)" "Gray"

$AllStepsSuccess = $true

# Function to run a script safely with state check
function Invoke-Step {
    param(
        [string]$ScriptName, # Filename with extension e.g. "AutoLogin.ps1"
        [bool]$Wait = $true,
        [bool]$Force = $false # If true, ignores state
    )

    $TaskKey = [System.IO.Path]::GetFileNameWithoutExtension($ScriptName)

    if (-not $Force -and (Test-Task $TaskKey)) {
        Write-Log "Skipping Task: $TaskKey (Already Complete)." "Gray"
        return
    }
    
    # Try current dir first, then System dir (legacy fallback)
    $Path = Join-Path $ScriptDir $ScriptName
    if (-not (Test-Path $Path)) {
        $Path = Join-Path $Global:SetupDir "Scripts\System\$ScriptName"
    }

    if (Test-Path $Path) {
        Write-Log "Running Post-Boot Task: $TaskKey..." "Cyan"
        try {
            if ($Wait) {
                & $Path
                if ($LASTEXITCODE -eq 0 -or $?) {
                    Set-TaskComplete $TaskKey
                    Write-Log "  -> Task '$TaskKey' Complete." "Green"
                } else {
                    Write-Log "  -> Task '$TaskKey' reported failure." "Red"
                    $script:AllStepsSuccess = $false
                }
            } else {
                Start-Process powershell.exe -ArgumentList "-NoExit", "-File `"$Path`""
                Set-TaskComplete $TaskKey 
            }
        } catch {
            Write-Log "  -> Error running '$TaskKey': $_" "Red"
            $script:AllStepsSuccess = $false
        }
    } else {
        Write-Log "Script not found: $ScriptName" "Red"
        $script:AllStepsSuccess = $false
    }
}

# 1. AutoLogin (First)
Invoke-Step "AutoLogin.ps1"

# 2. System Configuration (Resolution, Date, etc.)
Invoke-Step "FakeInstallDate.ps1"
Invoke-Step "SetResolution.ps1"
Invoke-Step "EjectDrive.ps1"

# 4. Run any "Other" scripts in this folder that are not explicitly ordered
# Exclude known ones
$Excluded = @("RunAfterBoot.ps1", "AutoLogin.ps1", "FakeInstallDate.ps1", "SetResolution.ps1", "EjectDrive.ps1", "SyncThingSetup.ps1", "ProxifierSetup.ps1")
$OtherScripts = Get-ChildItem -Path $ScriptDir -Filter "*.ps1" | Where-Object { $_.Name -notin $Excluded } | Sort-Object Name

foreach ($Script in $OtherScripts) {
    Invoke-Step $Script.Name
}

# 5. SyncThing (Second to last)
Invoke-Step "SyncThingSetup.ps1"

# 6. Proxifier (ALWAYS LAST)
Invoke-Step "ProxifierSetup.ps1"

# Cleanup Scheduled Task if everything finished successfully
if ($AllStepsSuccess) {
    Write-Log "All post-boot tasks completed successfully." "Green"
    Write-Log "Unregistering folder-opener task..." "Cyan"
    Unregister-ScheduledTask -TaskName "WindowsSetup_ManualStep" -Confirm:$false -ErrorAction SilentlyContinue
} else {
    Write-Log "Some tasks failed. Task retained for next retry." "Yellow"
}

Write-Header "POST-REBOOT SETUP COMPLETE"
Start-Sleep -Seconds 3