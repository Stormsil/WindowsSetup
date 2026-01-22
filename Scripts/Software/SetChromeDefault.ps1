# ==========================================
# SET CHROME AS DEFAULT BROWSER
# ==========================================
# Method: SetUserFTA (Bypasses UserChoice Hash protection)
# Requirement: SetUserFTA.exe must be downloaded and placed in the $ToolPath
# Note: Modern Windows (10/11) blocks direct Registry changes.

Write-Log "Configuring Google Chrome as Default Browser (SetUserFTA)..." "Cyan"

# 1. Setup Path to the tool
# Relative path: Up one level from Software/ -> Scripts/, then down to Tools/
$ToolsDir = Join-Path (Split-Path $PSScriptRoot -Parent) "Tools"
$ToolPath = Join-Path $ToolsDir "SetUserFTA.exe"

# 2. Check for Chrome Path
$ChromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $ChromePath)) {
    $ChromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
}

# Check if Chrome is installed
if (-not (Test-Path $ChromePath)) {
    Write-Log "WARNING: Google Chrome is not installed. Skipping default browser setup." "Yellow"
    return
}

# Check if SetUserFTA exists
if (-not (Test-Path $ToolPath)) {
    Write-Log "ERROR: SetUserFTA.exe not found at $ToolPath" "Red"
    Write-Log "Please download SetUserFTA and place it in the path above." "Red"
    return
}

try {
    # 3. Apply Associations
    Write-Log "Applying Chrome associations..." "Gray"

    # List of extensions and protocols
    $Associations = @(
        ".htm", 
        ".html", 
        ".shtml", 
        ".xht", 
        ".xhtml", 
        "http", 
        "https", 
        "ftp"
    )

    foreach ($assoc in $Associations) {
        # Execute SetUserFTA
        $proc = Start-Process -FilePath $ToolPath -ArgumentList "$assoc ChromeHTML" -PassThru -Wait -NoNewWindow
        
        if ($proc.ExitCode -eq 0) {
            Write-Log "[OK] $assoc -> Chrome" "Green"
        } else {
            Write-Log "[FAIL] $assoc (Error Code: $($proc.ExitCode))" "Red"
        }
    }
    
    # 4. Trigger UI Refresh
    Write-Log "Refreshing Explorer..." "Gray"
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue

    Write-Log "Chrome Default Browser configuration applied." "Green"

} catch {
    Write-Log "Error setting default browser: $_" "Red"
}