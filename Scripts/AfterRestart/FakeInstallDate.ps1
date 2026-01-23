# ==========================================
# FAKE WINDOWS INSTALL DATE
# ==========================================
# Randomizes the installation date between 0.5 and 1.5 years ago.

# Ensure the script is running with Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log "Error: This script must be run as Administrator." "Red"
    exit
}

# 1. Define the range in days (approx 0.5 to 1.5 years)
$minDays = 182
$maxDays = 547

# 2. Generate a random offset in seconds to make the time unique (not just the day)
$randomDays = Get-Random -Minimum $minDays -Maximum $maxDays
$randomSeconds = Get-Random -Minimum 0 -Maximum 86400

# 3. Calculate the target date
$targetDate = (Get-Date).AddDays(-$randomDays).AddSeconds(-$randomSeconds)

# 4. Convert to Unix Timestamp (for 'InstallDate')
$unixEpoch = Get-Date -Date "1970-01-01 00:00:00Z"
$unixTimestamp = [int64]($targetDate.ToUniversalTime() - $unixEpoch).TotalSeconds

# 5. Convert to Windows FILETIME (for 'InstallTime')
$fileTime = $targetDate.ToFileTime()

# 6. Registry Path
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

try {
    # Update InstallDate (DWORD/Unix Timestamp)
    Set-ItemProperty -Path $regPath -Name "InstallDate" -Value $unixTimestamp -Type DWord -Force
    
    # Update InstallTime (QWORD/FILETIME)
    Set-ItemProperty -Path $regPath -Name "InstallTime" -Value $fileTime -Type QWord -Force

    Write-Log "New Install Date set to: $($targetDate.ToString('yyyy-MM-dd HH:mm:ss'))" "Green"
}
catch {
    Write-Log "Error updating registry: $($_.Exception.Message)" "Red"
}
