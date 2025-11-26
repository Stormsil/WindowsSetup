# ==========================================
# WindowsSetup Orchestrator
# ==========================================
# This script acts as the "Task Runner". 
# It downloads files and executes scripts from the Scripts/ folder.

param(
    [string]$Token = ""
)

# 1. INIT
$Global:SetupDir = $PSScriptRoot
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Import Modules
Import-Module (Join-Path $SetupDir "Modules\Logger.psm1") -Force
Import-Module (Join-Path $SetupDir "Modules\StateManager.psm1") -Force
Import-Module (Join-Path $SetupDir "Modules\GitHubLoader.psm1") -Force
Import-Module (Join-Path $SetupDir "Modules\Utils.psm1") -Force

Write-Header "MAIN SETUP LOGIC STARTED"

# 2. CONFIG & DOWNLOAD
$SetupConfig = Get-SetupConfig

if (-not $Token) {
    Write-Log "WARNING: No GitHub Token provided! Private downloads will fail." "Red"
}
else {
    if ($SetupConfig) {
        Invoke-GitHubDownload -Token $Token -User $SetupConfig.GithubUser -Repo $SetupConfig.RepoName -Tag $SetupConfig.ReleaseTag -DestDir $SetupDir
    }
    else {
        Write-Log "ERROR: setup_config.json not found or invalid." "Red"
    }
}

# 3. EXECUTION PHASES
$Phases = @("System", "Network", "Drivers", "Software", "Final")

foreach ($Phase in $Phases) {
    Write-Header "PHASE: $Phase"
    
    $PhaseDir = Join-Path $SetupDir "Scripts\$Phase"
    if (Test-Path $PhaseDir) {
        $Scripts = Get-ChildItem -Path $PhaseDir -Filter "*.ps1" | Sort-Object Name
        
        foreach ($Script in $Scripts) {
            $TaskName = $Script.BaseName # e.g. "AutoLogin"
            
            # Check State
            if (Test-Task $TaskName) {
                Write-Log "Skipping Task: $TaskName (Already Complete)." "Gray"
                continue
            }
            
            Write-Log "Running Task: $TaskName..." "Cyan"
            try {
                # Execute Script
                & $Script.FullName
                
                # Mark Complete
                Set-TaskComplete $TaskName
                Write-Log "  -> Task '$TaskName' Complete." "Green"
            }
            catch {
                Write-Log "  -> Task '$TaskName' FAILED: $_" "Red"
            }
        }
    }
    else {
        Write-Log "Phase directory not found: $Phase" "Gray"
    }
}

# 4. COMPLETION
Write-Header "SETUP COMPLETE"
Write-Log "Closing automatically in 5 seconds..." "Gray"
Start-Sleep -Seconds 5