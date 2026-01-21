# CHECK 1: Is Nvidia GPU present?
$Gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" }

if ($Gpu) {
    Write-Log "NVIDIA GPU Detected: $($Gpu.Name)" "Green"
    
    # CHECK 2: Is Driver Installed? (If logic is flaky, we can rely on installer's self-check, but this is faster)
    # A generic driver often has "Microsoft Basic Display Adapter". A real one has the model name.
    # We assume if WMI reports the full model name, the driver is at least functional.
    
    # Optional: Check driver version if needed. For now, existence is enough.
    Write-Log "Driver appears to be installed. Skipping installer to save time." "Gray"
    return
} 
elseif (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match "Microsoft Basic Display Adapter" }) {
    # If we see Basic Adapter, we might have an Nvidia card needing drivers.
    Write-Log "Generic Video Adapter detected. Attempting Nvidia Driver Install..." "Cyan"
    Install-Program -Name "Nvidia Driver" -File "DRV_Nvidia.exe" -InstallArgs "-s"
}
else {
    # Fallback / Force Install if unsure
    Install-Program -Name "Nvidia Driver" -File "DRV_Nvidia.exe" -InstallArgs "-s"
}
