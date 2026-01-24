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
if (-not (Test-Task "MainSetup")) {
    $Phases = @("System", "Network", "Drivers", "Software")
    $TotalPhases = $Phases.Count
    $CurrentPhaseIdx = 0

    foreach ($Phase in $Phases) {
        $CurrentPhaseIdx++
        Write-Header "PHASE: $Phase"
        
        $PhaseDir = Join-Path $SetupDir "Scripts\$Phase"
        if (Test-Path $PhaseDir) {
            $Scripts = Get-ChildItem -Path $PhaseDir -Filter "*.ps1" | Sort-Object Name
            $ScriptCount = $Scripts.Count
            $CurrentScriptIdx = 0

            foreach ($Script in $Scripts) {
                $CurrentScriptIdx++
                $TaskName = $Script.BaseName # e.g. "AutoLogin"
                
                # Progress Bar
                $PercentComplete = [int](($CurrentPhaseIdx - 1) / $TotalPhases * 100 + ($CurrentScriptIdx / $ScriptCount * (100 / $TotalPhases)))
                Write-Progress -Activity "Windows Setup Progress" -Status "Phase: $Phase ($CurrentPhaseIdx/$TotalPhases)" -CurrentOperation "Running: $TaskName" -PercentComplete $PercentComplete

                # Tasks that handle their own state (Idempotent) - Safe to run every time
                $IdempotentTasks = @("Apps", "AutoLogin", "Privacy", "MAS")

                # Check State (Skip if done AND not idempotent)
                if ($TaskName -notin $IdempotentTasks -and (Test-Task $TaskName)) {
                    Write-Log "Skipping Task: $TaskName (Already Complete)." "Gray"
                    continue
                }
                
                Write-Log "Running Task: $TaskName..." "Cyan"
                try {
                    # Execute Script
                    & $Script.FullName
                    
                    # Mark Complete (Update timestamp/status)
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
    
    # Mark Main Setup as Complete so next time we skip this block
    Set-TaskComplete "MainSetup"
    
    # 4. COMPLETION & NEXT BOOT SETUP (First Run)
    Write-Header "SETUP COMPLETE"
    Write-Log "Configuring Post-Reboot tasks (Scheduled Task)..." "Cyan"

    $AfterBootScript = Join-Path $SetupDir "Scripts\AfterRestart\RunAfterBoot.ps1"
    if (Test-Path $AfterBootScript) {
        # Create Scheduled Task Action
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$AfterBootScript`""
        
        # Create Trigger (AtLogon)
        $Trigger = New-ScheduledTaskTrigger -AtLogon
        
        # Create Principal (Run as Admin/System)
        $Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest

        # Register Task
        $TaskName = "WindowsSetup_PostBoot"
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
        
        Write-Log "  -> Registered Scheduled Task '$TaskName' for next login." "Green"
    } else {
        Write-Log "  -> RunAfterBoot.ps1 not found!" "Red"
    }

    Write-Progress -Activity "Windows Setup Progress" -Completed
    
    # Telegram Notification
    try {
        $vmName = Get-VmName
        $botToken = "8535757715:AAGU_eMN6abKWANdaZ4kY_YTRfenvhQSZXA"
        $chatID = "570723201"
        $message = "✅ Setup Complete! [$vmName] - Restarting VM..."
        Write-Log "Sending Telegram notification for $vmName..." "Gray"
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" -Method Post -Body @{chat_id=$chatID; text=$message} -ErrorAction SilentlyContinue | Out-Null
    } catch {
        Write-Log "Failed to send Telegram notification." "Yellow"
    }

    Write-Log "All tasks finished. System will reboot in 10 seconds to apply all changes." "Yellow"

    # Final Countdown & Reboot
    for ($i = 10; $i -gt 0; $i--) {
        Write-Log "Rebooting in $i..." "Gray"
        Start-Sleep -Seconds 1
    }

    Restart-Computer -Force

} else {
    Write-Header "MAIN SETUP ALREADY COMPLETE"
    Write-Log "Skipping primary phases. Checking 'AfterRestart' scripts..." "Cyan"
    
    # Direct execution of post-boot scripts (Update Mode)
    $AfterBootScript = Join-Path $SetupDir "Scripts\AfterRestart\RunAfterBoot.ps1"
    if (Test-Path $AfterBootScript) {
        & $AfterBootScript
    } else {
        Write-Log "RunAfterBoot.ps1 not found!" "Red"
    }
}