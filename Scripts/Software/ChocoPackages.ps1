# ==========================================
# ROBUST CHOCOLATEY INSTALLER
# ==========================================
# Reads packages from setup_config.json
# Installs them one by one, skipping failures without stopping the script.

$SetupConfig = Get-SetupConfig

if (-not (Get-Command "choco" -ErrorAction SilentlyContinue)) {
    Write-Log "ERROR: Chocolatey not found! Skipping packages." "Red"
    return
}

if (-not $SetupConfig.choco_packages) {
    Write-Log "WARNING: No packages defined in setup_config.json" "Yellow"
    return
}

Write-Log "Starting Package Installation..." "Cyan"

$totalPpkgs = $SetupConfig.choco_packages.Count
$currentPkgIdx = 0

foreach ($pkg in $SetupConfig.choco_packages) {
    $currentPkgIdx++
    Write-Progress -Activity "Installing Chocolatey Packages" -Status "Package: $pkg ($currentPkgIdx/$totalPpkgs)" -PercentComplete ([int]($currentPkgIdx / $totalPpkgs * 100))
    
    Write-Host -NoNewline "[...] Checking $pkg ... " -ForegroundColor Gray
    
    # Check if installed (simple check)
    $isInstalled = choco list --local-only --exact $pkg --limit-output
    
    if ($isInstalled) {
        Write-Host "INSTALLED" -ForegroundColor Green
    } else {
        Write-Host "INSTALLING" -ForegroundColor Cyan
        
        try {
            # Run install with Retry
            Invoke-Retry -MaxAttempts 3 -DelaySeconds 5 -Action {
                $proc = Start-Process "choco" -ArgumentList "install $pkg -y --no-progress --ignore-checksums" -NoNewWindow -Wait -PassThru
                
                if ($proc.ExitCode -eq 0) {
                    Write-Log "  -> $pkg Installed Successfully." "Green"
                } elseif ($proc.ExitCode -eq 3010) {
                    Write-Log "  -> $pkg Installed (Reboot Required)." "Yellow"
                } else {
                    throw "$pkg Failed (Exit Code: $($proc.ExitCode))"
                }
            }
        } catch {
            Write-Log "  -> Error installing $($pkg): $_" "Red"
        }
    }
}