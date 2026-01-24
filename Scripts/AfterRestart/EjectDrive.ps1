# ==========================================
# EJECT ISO AND DVD DRIVES
# ==========================================

function Write-Log {
    param($Msg, $Col = "White")
    Write-Host "[Eject] $Msg" -ForegroundColor $Col
}

function Eject-IsoAndDvd {
    Write-Log "Scanning for Optical Drives (CD/DVD/ISO)..." "Cyan"

    $opticalDrives = Get-CimInstance -ClassName Win32_Volume | Where-Object { $_.DriveType -eq 5 }

    if ($opticalDrives) {
        $shell = New-Object -ComObject Shell.Application
        foreach ($vol in $opticalDrives) {
            $driveLetter = $vol.DriveLetter
            if ($driveLetter) {
                Write-Log "Found Drive: $driveLetter ($($vol.Label)). Ejecting..." "Yellow"
                try {
                    $shell.Namespace(17).ParseName($driveLetter).InvokeVerb("Eject")
                    Write-Log "  -> OK" "Green"
                } catch {
                    Write-Log "  -> FAILED: $($_.Exception.Message)" "Red"
                }
            }
        }
    } else {
        Write-Log "No Optical/ISO drives found." "Gray"
    }
}

Eject-IsoAndDvd