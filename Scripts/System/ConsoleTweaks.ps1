Write-Log "Configuring Console..." "Gray"
$consolePath = "HKCU:\Console"
if (-not (Test-Path $consolePath)) { New-Item $consolePath -Force | Out-Null }
New-ItemProperty -Path $consolePath -Name "WindowSize" -Value 0x001E005A -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $consolePath -Name "WindowPosition" -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $consolePath -Name "ScreenBufferSize" -Value 0x2328005A -PropertyType DWord -Force | Out-Null
