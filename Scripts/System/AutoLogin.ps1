Write-Log "Setting up Auto-Login (User: Alex)..." "Gray"
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$devicePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"

if (-not (Test-Path $devicePath)) { New-Item $devicePath -Force | Out-Null }
New-ItemProperty -Path $devicePath   -Name "DevicePasswordLessBuildVersion" -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Value "Alex" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Value "1204" -PropertyType String -Force | Out-Null
