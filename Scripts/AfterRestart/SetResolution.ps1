# ==========================================
# SET RESOLUTION (VIA QRES)
# ==========================================

function Write-Log {
    param($Msg, $Col = "White")
    Write-Host "[Resolution] $Msg" -ForegroundColor $Col
}

# Auto-calculate Tool Path
$CurrentDir = $PSScriptRoot
# Try to find Tools folder (it's in Scripts/Tools)
$ToolsDir = Join-Path (Split-Path $CurrentDir -Parent) "Tools"
$ToolPath = Join-Path $ToolsDir "QRes.exe"

$Width = 1920
$Height = 1080
$RefreshRate = 60

function Run-QRes {
    if (-not (Test-Path $ToolPath)) {
        Write-Log "ERROR: QRes.exe not found at: $ToolPath" "Red"
        return
    }

    Write-Log "Setting resolution: ${Width}x${Height} @ ${RefreshRate}Hz" "Cyan"
    
    # Execute QRes
    & $ToolPath /x:$Width /y:$Height /r:$RefreshRate | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Log "SUCCESS: Resolution applied." "Green"
    } else {
        Write-Log "QRes finished (Code: $LASTEXITCODE)." "Gray"
    }
}

Run-QRes