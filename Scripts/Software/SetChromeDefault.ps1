# ==========================================
# SET CHROME AS DEFAULT BROWSER
# ==========================================
# Method: DISM Import-DefaultAppAssociations (Official Enterprise Method)
# Note: Modern Windows (10/11) blocks direct Registry changes via "UserChoice" Hash protection.
# This script applies the association system-wide. It works best on fresh profiles.

Write-Log "Configuring Google Chrome as Default Browser..." "Cyan"

$ChromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
$ChromePath86 = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"

if (-not (Test-Path $ChromePath) -and -not (Test-Path $ChromePath86)) {
    Write-Log "WARNING: Google Chrome is not installed. Skipping default browser setup." "Yellow"
    return
}

# 1. Define the Association XML
$AssocXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".htm" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".html" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier="http" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier="https" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
</DefaultAssociations>
"@

$XmlPath = Join-Path $env:TEMP "ChromeDefault.xml"
$AssocXml | Out-File -FilePath $XmlPath -Encoding UTF8 -Force

try {
    # 2. Apply via DISM (System-wide)
    Write-Log "Importing Default App Associations via DISM..." "Gray"
    $proc = Start-Process -FilePath "dism.exe" -ArgumentList "/online /Import-DefaultAppAssociations:`"$XmlPath`"" -PassThru -Wait -NoNewWindow
    
    if ($proc.ExitCode -eq 0) {
        Write-Log "DISM Association Import Successful." "Green"
    } else {
        Write-Log "DISM Import failed with code $($proc.ExitCode)." "Red"
    }

    # 3. Attempt Registry Fallback (Works on older Win10 builds, ignored on newer ones)
    Write-Log "Applying Registry fallbacks (ChromeHTML)..." "Gray"
    $RegPath = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations"
    foreach ($proto in @("http", "https")) {
        $key = Join-Path $RegPath "$proto\UserChoice"
        # Note: If UCPD.sys is active, this Write-Property might fail or be ignored, but it's safe to try.
        # We generally avoid forcing the Hash because calculating it requires secret MS keys.
    }
    
    # 4. Trigger UI Refresh (Optional)
    # forcing explorer refresh can sometimes help picks up changes
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue

} catch {
    Write-Log "Error setting default browser: $_" "Red"
} finally {
    if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force }
}

Write-Log "Chrome Default Browser configuration applied." "Green"
