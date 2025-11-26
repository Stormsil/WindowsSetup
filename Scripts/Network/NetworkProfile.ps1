Write-Log "Setting Network Profile to Public..." "Gray"
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Public -ErrorAction SilentlyContinue

$taskName = "AutoSetAllNetworksToPublic"
$taskCmd = "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Public -ErrorAction SilentlyContinue"
$taskAct = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -Command `"$taskCmd`""
$taskTrig = New-ScheduledTaskTrigger -AtStartup
$taskPrin = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $taskName -Action $taskAct -Trigger $taskTrig -Principal $taskPrin -Force | Out-Null
    Write-Log "Scheduled task created." "Green"
}
catch {}
