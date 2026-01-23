# ==========================================
# SET RESOLUTION (VIA QRES)
# ==========================================

$ScriptDir = $PSScriptRoot
$Global:SetupDir = Resolve-Path (Join-Path $ScriptDir "..\..")

# --- SETTINGS ---
$ToolPath = Join-Path $Global:SetupDir "Scripts\Tools\QRes.exe"
$Width = 1920
$Height = 1080
$RefreshRate = 60
# ----------------

function Run-QRes {
    # 1. Check if QRes exists
    if (-not (Test-Path $ToolPath)) {
        Write-Host "ERROR: QRes.exe not found at: $ToolPath" -ForegroundColor Red
        return
    }

    Write-Host "QRes found. Checking available modes..." -ForegroundColor Cyan
    
    # 2. Debug: List available modes (Switch /L)
    # Using Start-Process to capture output if needed, but here just running it
    & $ToolPath /L
    
    Write-Host "`n----------------------------------------"
    Write-Host "Attempting to set resolution: ${Width}x${Height} @ ${RefreshRate}Hz" -ForegroundColor Yellow
    
    # 3. Execute with arguments: /x:Width /y:Height /r:Rate
    # QRes usually returns immediately
    & $ToolPath /x:$Width /y:$Height /r:$RefreshRate

    # Check for success (simple check)
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS: QRes command sent." -ForegroundColor Green
    } else {
        Write-Host "QRes Exit Code: $LASTEXITCODE. This might be normal if resolution changed." -ForegroundColor Gray
    }
}

Run-QRes