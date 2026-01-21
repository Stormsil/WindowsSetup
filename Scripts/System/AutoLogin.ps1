# ==========================================
# ROBUST AUTO-LOGIN CONFIG
# ==========================================
$SetupConfig = Get-SetupConfig

if (-not $SetupConfig.system_user.autologin) {
    Write-Log "Auto-Login disabled in config. Skipping." "Gray"
    return
}

$User = $SetupConfig.system_user.name
$Pass = $SetupConfig.system_user.password

Write-Log "Configuring Auto-Login for user: $User" "Cyan"

# 1. Create User if missing (Modern Method)
$UserObj = Get-LocalUser -Name $User -ErrorAction SilentlyContinue

if (-not $UserObj) {
    Write-Log "User '$User' not found. Creating..." "Yellow"
    try {
        $SecurePass = $Pass | ConvertTo-SecureString -AsPlainText -Force
        New-LocalUser -Name $User -Password $SecurePass -PasswordNeverExpires -Description "Created by WindowsSetup" | Out-Null
        Add-LocalGroupMember -Group "Administrators" -Member $User -ErrorAction SilentlyContinue
        Write-Log "User created and added to Admin group." "Green"
    } catch {
        Write-Log "Failed to create user (Modern): $_. Falling back to legacy..." "Red"
        # Fallback to legacy just in case
        net user "$User" "$Pass" /add /Y | Out-Null
        net localgroup Administrators "$User" /add | Out-Null
    }
} else {
    # Update password to match config
    Write-Log "User exists. Ensuring password matches..." "Gray"
    try {
        $SecurePass = $Pass | ConvertTo-SecureString -AsPlainText -Force
        Set-LocalUser -Name $User -Password $SecurePass
    } catch {
        Write-Log "Failed to update password: $_" "Yellow"
    }
}

# 2. Disable "Windows Hello Requirement" (Critical for AutoLogin)
$devicePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
if (-not (Test-Path $devicePath)) { New-Item $devicePath -Force | Out-Null }
Set-ItemProperty -Path $devicePath -Name "DevicePasswordLessBuildVersion" -Value 0 -Type DWord -Force | Out-Null

# 3. Set Winlogon Registry Keys
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -Type String -Force | Out-Null
Set-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Value $User -Type String -Force | Out-Null
Set-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -Value "." -Type String -Force | Out-Null
Set-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Value $Pass -Type String -Force | Out-Null

Write-Log "Auto-Login Configured for $User. (Reboot required)" "Green"