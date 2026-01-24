$FileName = "SYS_vcredist.zip"
$ZipFile = Join-Path $Global:SetupDir "GitReleaseDownloaded\$FileName"
$ExtractDir = Join-Path $Global:SetupDir "VCRedist"

if (Test-Path $ZipFile) {
    Write-Log "Extracting VCRedist..." "Cyan"
    if (Test-Path $ExtractDir) { Remove-Item $ExtractDir -Recurse -Force }
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
    Expand-Archive -Path $ZipFile -DestinationPath $ExtractDir -Force
    
    # Delete ZIP immediately after extraction to save space
    Write-Log "Removing ZIP file to save space..." "Gray"
    Remove-Item $ZipFile -Force

    # Try to find install_all.bat
    $BatPath = Join-Path $ExtractDir "install_all.bat"
    if (-not (Test-Path $BatPath)) {
        $BatPath = Join-Path $ExtractDir "vcredist\install_all.bat"
    }
    
    if (Test-Path $BatPath) {
        Write-Log "Executing VCRedist installer..." "Gray"
        Start-Process "cmd.exe" -ArgumentList "/c `"$BatPath`"" -Wait -NoNewWindow
        Write-Log "VCRedist Installation finished." "Green"
    } else {
        Write-Log "ERROR: install_all.bat not found in $ExtractDir." "Red"
    }
}
else {
    # Check if already extracted (in case script runs again)
    if (Test-Path $ExtractDir) {
        Write-Log "VCRedist already extracted, running from folder..." "Green"
        $BatPath = Join-Path $ExtractDir "install_all.bat"
        if (-not (Test-Path $BatPath)) { $BatPath = Join-Path $ExtractDir "vcredist\install_all.bat" }
        if (Test-Path $BatPath) { Start-Process "cmd.exe" -ArgumentList "/c `"$BatPath`"" -Wait -NoNewWindow }
    } else {
        Write-Log "Skipping VCRedist: Archive not found." "Gray"
    }
}
