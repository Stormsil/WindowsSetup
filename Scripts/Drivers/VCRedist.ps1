$ZipFile = Join-Path $Global:SetupDir "SYS_vcredist.zip"
if (Test-Path $ZipFile) {
    Write-Log "Unzipping VCRedist..." "Cyan"
    Expand-Archive -Path $ZipFile -DestinationPath $Global:SetupDir -Force
    
    # Try to find install_all.bat in root or subfolder
    $BatPath = "install_all.bat"
    if (-not (Test-Path (Join-Path $Global:SetupDir $BatPath))) {
        $BatPath = "vcredist\install_all.bat"
    }
    
    Invoke-BatchFile -File $BatPath
}
else {
    Write-Log "Skipping VCRedist: Zip not found." "Gray"
}
