Write-Log "Disabling News and Interests (Weather Widget)..." "Gray"
$feedsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"

if (-not (Test-Path $feedsPath)) { New-Item $feedsPath -Force | Out-Null }

# 0 = Show icon and text
# 1 = Show icon only
# 2 = Turn off
New-ItemProperty -Path $feedsPath -Name "ShellFeedsTaskbarViewMode" -Value 2 -PropertyType DWord -Force | Out-Null
Write-Log "  -> News and Interests disabled." "Green"
