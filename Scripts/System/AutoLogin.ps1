# ==========================================
# ROBUST AUTO-LOGIN CONFIG (INTEGRATED)
# ==========================================
$SetupConfig = Get-SetupConfig

if (-not $SetupConfig.system_user.autologin) {
    Write-Log "Auto-Login disabled in config. Skipping." "Gray"
    return
}

$User = $SetupConfig.system_user.name
$Pass = $SetupConfig.system_user.password
# Убедитесь, что путь к утилите корректен. Обычно он лежит в Tools.
$AutologonExe = "C:\WindowsSetup\System\Scripts\Tools\Autologon64.exe"

Write-Log "Configuring Auto-Login for user: $User" "Cyan"

# ---------------------------------------------------------
# 1. Create User if missing (Modern Method)
# ---------------------------------------------------------
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

# ---------------------------------------------------------
# 2. Disable "Windows Hello Requirement" (Critical for AutoLogin)
# ---------------------------------------------------------
$devicePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
if (-not (Test-Path $devicePath)) { New-Item $devicePath -Force | Out-Null }
Set-ItemProperty -Path $devicePath -Name "DevicePasswordLessBuildVersion" -Value 0 -Type DWord -Force | Out-Null

# ---------------------------------------------------------
# 3. Configure Auto-Login (Sysinternals vs Registry Fallback)
# ---------------------------------------------------------
if (Test-Path $AutologonExe) {
    Write-Log "Autologon tool found ($AutologonExe). Configuring securely..." "Cyan"
    
    # 3.1. Pre-accept EULA via Registry to avoid GUI popup
    $regPath = "HKCU:\Software\Sysinternals\Autologon"
    if (-not (Test-Path $regPath)) { New-Item $regPath -Force | Out-Null }
    Set-ItemProperty -Path $regPath -Name "EulaAccepted" -Value 1 -Type DWord -Force | Out-Null

    # 3.2. Execute Autologon.exe
    # Syntax: autologon <username> <domain> <password>
    try {
        & $AutologonExe $User "." $Pass
        Write-Log "Auto-Login Configured via Sysinternals (Encrypted)." "Green"
    } catch {
        Write-Log "Error executing Autologon.exe: $_" "Red"
    }
} else {
    Write-Log "Autologon.exe not found. Falling back to Registry method (Clear Text)." "Yellow"
    
    # Fallback: Set Winlogon Registry Keys manually
    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -Type String -Force | Out-Null
    Set-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Value $User -Type String -Force | Out-Null
    Set-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -Value "." -Type String -Force | Out-Null
    Set-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Value $Pass -Type String -Force | Out-Null
    Set-ItemProperty -Path $winlogonPath -Name "ForceAutoLogon" -Value "1" -Type String -Force | Out-Null
    
    Write-Log "Auto-Login Configured via Registry." "Green"
}