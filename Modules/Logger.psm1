$LogFile = "C:\WindowsSetup\setup.log"

function Write-Log { 
    param(
        [string]$Msg, 
        [string]$Color="White"
    ) 
    $TimeStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $LogMsg = "[$TimeStamp] $Msg"
    
    # Console Output
    Write-Host "[SETUP] $((Get-Date).ToString('HH:mm:ss')) $Msg" -ForegroundColor $Color 
    
    # File Output
    try {
        $LogDir = Split-Path $LogFile
        if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
        $LogMsg | Out-File -FilePath $LogFile -Append -Encoding UTF8
    } catch {}
}

function Write-Header {
    param(
        [string]$Title
    )
    $Line = "=========================================="
    Write-Log ""
    Write-Log $Line "Cyan"
    Write-Log "   $Title" "Cyan"
    Write-Log $Line "Cyan"
    Write-Log ""
}

Export-ModuleMember -Function Write-Log, Write-Header
