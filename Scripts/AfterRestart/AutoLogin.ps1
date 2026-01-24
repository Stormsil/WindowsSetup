# ========================================== 
# STANDALONE AUTO-LOGIN CONFIG 
# ========================================== 
# This script is independent and has hardcoded credentials.

$User = "User"
$Pass = "1204"

function Write-Log {
    param($Msg, $Col = "White")
    Write-Host "[AutoLogin] $Msg" -ForegroundColor $Col
}

# Determine Tools path relative to this script
# From Scripts\System\ -> up to Scripts\ -> down to Tools\
$ToolsDir = Join-Path (Split-Path $PSScriptRoot -Parent) "Tools"
$AutologonExe = Join-Path $ToolsDir "Autologon64.exe"

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
        net user "$User" "$Pass" /add /Y | Out-Null
        net localgroup Administrators "$User" /add | Out-Null
    }
} else {
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
# 3. Configure Auto-Login 
# --------------------------------------------------------- 
if (Test-Path $AutologonExe) {
    Write-Log "Autologon tool found ($AutologonExe). Configuring..." "Cyan"
    
    # Pre-accept EULA via Registry to avoid GUI popup
    $regPath = "HKCU:\Software\Sysinternals\Autologon"
    if (-not (Test-Path $regPath)) { New-Item $regPath -Force | Out-Null }
    Set-ItemProperty -Path $regPath -Name "EulaAccepted" -Value 1 -Type DWord -Force | Out-Null

    try {
        & $AutologonExe $User "." $Pass /AcceptEula
        Write-Log "Auto-Login Configured via Sysinternals." "Green"
    } catch {
        Write-Log "Error executing Autologon.exe: $_" "Red"
    }
} 

# Always apply Registry fallback just to be 100% sure (some builds ignore Autologon.exe)
Write-Log "Applying Registry Winlogon overrides..." "Gray"
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -Type String -Force | Out-Null
Set-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Value $User -Type String -Force | Out-Null
Set-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -Value "." -Type String -Force | Out-Null
Set-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Value $Pass -Type String -Force | Out-Null
Set-ItemProperty -Path $winlogonPath -Name "ForceAutoLogon" -Value "1" -Type String -Force | Out-Null

Write-Log "Auto-Login setup complete." "Green"
