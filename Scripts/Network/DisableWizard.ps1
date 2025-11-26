Write-Log "Disabling Network Location Wizard..." "Gray"
$netPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff"
if (-not (Test-Path $netPath)) { New-Item $netPath -Force | Out-Null }
New-ItemProperty -Path $netPath -Name "Default" -Value "" -PropertyType String -Force | Out-Null
