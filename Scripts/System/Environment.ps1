Write-Log "Configuring environment variables..." "Gray"
[Environment]::SetEnvironmentVariable("OPENCV_SKIP_CPU_BASELINE_CHECK", "1", "User")
