# Only specific Tetherscript devices
$devicesToDisable = @(
    "Tetherscript Virtual Gamepad",
    "Tetherscript Virtual Joystick"
)

Write-Host "Processing Tetherscript devices..." -ForegroundColor Cyan

foreach ($name in $devicesToDisable) {
    # Find device by name
    $devs = Get-PnpDevice -FriendlyName $name -ErrorAction SilentlyContinue

    if ($devs) {
        foreach ($dev in $devs) {
            # Check if active
            if ($dev.Status -eq 'OK') {
                Write-Host "Disabling: $($dev.FriendlyName)" -ForegroundColor Yellow
                Disable-PnpDevice -InputObject $dev -Confirm:$false
            } else {
                Write-Host "Already disabled: $($dev.FriendlyName)" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "Device not found: $name" -ForegroundColor Red
    }
}

Write-Host "Done." -ForegroundColor Green