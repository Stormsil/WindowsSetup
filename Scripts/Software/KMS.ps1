# ==========================================
# WINDOWS ACTIVATION (MAS - HWID)
# ==========================================
# Uses Microsoft Activation Scripts (MassGrave) in unattended mode.
# Documentation: https://massgrave.dev

Write-Log "Checking Activation Status..." "Cyan"

# 1. Check if already permanently activated
$License = Get-CimInstance SoftwareLicensingProduct | Where-Object { $_.PartialProductKey -and $_.Name -like "Windows*" } | Select-Object -First 1
if ($License.LicenseStatus -eq 1) {
    Write-Log "Windows is already activated." "Green"
    return
}

Write-Log "Starting Windows Activation (HWID)..." "Cyan"

try {
    # Check Internet
    if (Test-Connection "8.8.8.8" -Count 1 -Quiet) {
        
        # Execute MAS in unattended HWID mode with Retry
        Invoke-Retry -MaxAttempts 3 -DelaySeconds 5 -Action {
             Write-Log "Downloading and executing MAS..." "Gray"
             & ([ScriptBlock]::Create((irm https://massgrave.dev/get))) /HWID
        }
        
        Write-Log "Activation logic completed." "Green"
    } else {
        Write-Log "No Internet connection. Skipping Activation." "Red"
    }
} catch {
    Write-Log "Activation Error: $_" "Red"
}