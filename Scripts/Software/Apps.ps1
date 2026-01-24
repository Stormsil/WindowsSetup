# ==========================================
# DIRECT EXE APPS INSTALLER
# ==========================================
# Reads apps from setup_config.json and installs them using Install-Program utility.

$SetupConfig = Get-SetupConfig

if (-not $SetupConfig.apps) {
    Write-Log "WARNING: No apps defined in setup_config.json" "Yellow"
    return
}

Write-Log "Starting Direct App Installation..." "Cyan"

$totalApps = $SetupConfig.apps.Count
$currentAppIdx = 0

foreach ($app in $SetupConfig.apps) {
    $currentAppIdx++
    Write-Progress -Activity "Installing Applications" -Status "App: $($app.name) ($currentAppIdx/$totalApps)" -PercentComplete ([int]($currentAppIdx / $totalApps * 100))
    
    # Use Install-Program utility from Utils.psm1
    Install-Program -Name $app.name `
                    -File $app.file `
                    -InstallArgs $app.args `
                    -CheckRegistry $app.registry
}
