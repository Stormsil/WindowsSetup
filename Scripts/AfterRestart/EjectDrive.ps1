# ==========================================
# EJECT ISO AND DVD DRIVES
# ==========================================

function Eject-IsoAndDvd {
    Write-Host "Scanning for Optical Drives (CD/DVD/ISO)..." -ForegroundColor Cyan

    # Find all drives with DriveType = 5 (CD-ROM/DVD/ISO)
    $opticalDrives = Get-CimInstance -ClassName Win32_Volume | Where-Object { $_.DriveType -eq 5 }

    if ($opticalDrives) {
        $shell = New-Object -ComObject Shell.Application
        
        foreach ($vol in $opticalDrives) {
            $driveLetter = $vol.DriveLetter
            
            if ($driveLetter) {
                Write-Host "Found Drive: $driveLetter ($($vol.Label))" -ForegroundColor Yellow
                Write-Host "Attempting to eject..." -NoNewline
                
                try {
                    # Use Shell Namespace to invoke the native "Eject" verb
                    $shell.Namespace(17).ParseName($driveLetter).InvokeVerb("Eject")
                    Write-Host " [OK]" -ForegroundColor Green
                }
                catch {
                    Write-Host " [FAILED]" -ForegroundColor Red
                    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    } else {
        Write-Host "No Optical/ISO drives found." -ForegroundColor Gray
    }
}

Eject-IsoAndDvd