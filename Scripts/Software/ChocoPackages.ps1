$chocoApps = @(
    "dotnet-8.0-sdk",
    "webview2-runtime",
    "googlechrome",  
    "notepadplusplus",
    "winrar"
)

if (Get-Command "choco" -ErrorAction SilentlyContinue) {
    Write-Log "Installing Choco Packages..." "Yellow"
    choco upgrade $chocoApps -y --no-progress --stop-on-first-failure
}
