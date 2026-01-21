# ==========================================
# WINDOWS PRIVACY & DEBLOAT (Win11Debloat Offline)
# ==========================================
# Uses local Win11Debloat zip provided in Scripts folder.

Write-Log "Initializing System Debloat..." "Cyan"

# 1. Locate the Zip
$ZipFile = Get-ChildItem -Path (Join-Path $Global:SetupDir "Scripts\Tools") -Filter "Win11Debloat*.zip" | Select-Object -First 1

if ($ZipFile) {
    $ExtractDir = Join-Path $env:TEMP "Win11Debloat_Setup"
    
    # 2. Extract
    Write-Log "Extracting $($ZipFile.Name)..." "Gray"
    if (Test-Path $ExtractDir) { Remove-Item $ExtractDir -Recurse -Force }
    Expand-Archive -Path $ZipFile.FullName -DestinationPath $ExtractDir -Force
    
    # 3. Find the script
    $DebloatScript = Get-ChildItem -Path $ExtractDir -Filter "Win11Debloat.ps1" -Recurse | Select-Object -First 1
    
    if ($DebloatScript) {
        Write-Log "Running Win11Debloat..." "Cyan"
        
        # Arguments for Safe Privacy & Debloat
        # -RunDefaultsLite: Standard clean without removing apps (user manages apps via other means)
        # -Silent: No prompts
        $ArgsList = "-RunDefaultsLite -Silent"
        
        try {
            # Execution
            # Added WorkingDirectory to ensure script finds its config files
            $Proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Unrestricted -File `"$($DebloatScript.FullName)`" $ArgsList" -Verb RunAs -PassThru -Wait -WorkingDirectory $ExtractDir
            
            if ($Proc.ExitCode -eq 0) {
                Write-Log "Debloat applied successfully." "Green"
            } else {
                 Write-Log "Debloat finished with code $($Proc.ExitCode)." "Yellow"
            }
        } catch {
            Write-Log "Failed to execute Debloat script: $_" "Red"
        }
        
        # Cleanup
        Remove-Item $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        
    } else {
        Write-Log "ERROR: Win11Debloat.ps1 not found in archive." "Red"
    }
} else {
    Write-Log "WARNING: Win11Debloat zip not found in Scripts folder. Skipping." "Yellow"
}
