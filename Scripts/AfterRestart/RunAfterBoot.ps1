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

# Function to run a script safely with state check
function Invoke-Step {
    param(
        [string]$ScriptName, 
        [bool]$Wait = $true,
        [bool]$Force = $false # If true, ignores state
    )

    if (-not $Force -and (Test-Task $ScriptName)) {
        Write-Log "Skipping Task: $ScriptName (Already Complete)." "Gray"
        return
    }
    
    # Try current dir first, then System dir (legacy fallback)
    $Path = Join-Path $ScriptDir $ScriptName
    if (-not (Test-Path $Path)) {
        $Path = Join-Path $Global:SetupDir "Scripts\System\$ScriptName"
    }

    if (Test-Path $Path) {
        Write-Log "Running Post-Boot Task: $ScriptName..." "Cyan"
        try {
            if ($Wait) {
                & $Path
                if ($LASTEXITCODE -eq 0 -or $?) {
                    Set-TaskComplete $ScriptName
                    Write-Log "  -> Task '$ScriptName' Complete." "Green"
                } else {
                    Write-Log "  -> Task '$ScriptName' reported failure." "Red"
                }
            } else {
                Start-Process powershell.exe -ArgumentList "-NoExit", "-File `"$Path`""
                Set-TaskComplete $ScriptName # Mark complete if we fired and forgot? Usually better to wait.
            }
        } catch {
            Write-Log "  -> Error running '$ScriptName': $_" "Red"
        }
    } else {
        Write-Log "Script not found: $ScriptName" "Red"
    }
}

# 1. AutoLogin (First)
Invoke-Step "AutoLogin.ps1"

# 2. System Configuration (Resolution, Date, etc.)
Invoke-Step "FakeInstallDate.ps1"
Invoke-Step "SetResolution.ps1"

# 3. Disk Ejection (Logic wrapped as task)
if (-not (Test-Task "DiskEject")) {
    try {
        Write-Log "Attempting to Eject Drive D:..." "Yellow"
        $driveLetter = "D:"
        $eject = New-Object -ComObject Shell.Application
        $eject.Namespace(17).ParseName($driveLetter).InvokeVerb("Eject")
        Write-Log "  -> Eject command sent." "Green"
        Set-TaskComplete "DiskEject"
    } catch {
        Write-Log "  -> Failed to eject D: (might not exist or be in use)." "Gray"
    }
} else {
    Write-Log "Skipping Task: DiskEject (Already Complete)." "Gray"
}

# 4. Run any "Other" scripts in this folder that are not explicitly ordered
# Exclude known ones
$Excluded = @("RunAfterBoot.ps1", "AutoLogin.ps1", "FakeInstallDate.ps1", "SetResolution.ps1", "SyncThingSetup.ps1", "ProxifierSetup.ps1")
$OtherScripts = Get-ChildItem -Path $ScriptDir -Filter "*.ps1" | Where-Object { $_.Name -notin $Excluded } | Sort-Object Name

foreach ($Script in $OtherScripts) {
    Invoke-Step $Script.Name
}

# 5. SyncThing (Second to last)
Invoke-Step "SyncThingSetup.ps1"

# 6. Proxifier (ALWAYS LAST)
Invoke-Step "ProxifierSetup.ps1"

# Cleanup Scheduled Task if everything finished successfully?
# Only if we want to stop it running on NEXT boot. 
# But the user might want 'idempotency' on every boot?
# "RunAfterBoot acts as the orchestrator".
# If we unregister, it won't run again.
# The user said: "if I decide to add a new script... I want to press START... it re-downloads... then runs new scripts".
# This implies 'RunAfterBoot' is triggered by 'Main.ps1' manually, OR automatically at boot.
# If 'Main.ps1' registers the task, it runs at boot.
# I will NOT unregister it automatically, so it can handle future updates if the user reboots.
# OR, if the user runs 'Start' (Main.ps1), it manually invokes this script too.

Write-Header "POST-REBOOT SETUP COMPLETE"
Start-Sleep -Seconds 3