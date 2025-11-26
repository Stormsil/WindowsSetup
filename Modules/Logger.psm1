function Write-Log { 
    param(
        [string]$Msg, 
        [string]$Color="White"
    ) 
    Write-Host "[SETUP] $((Get-Date).ToString('HH:mm:ss')) $Msg" -ForegroundColor $Color 
}

function Write-Header {
    param(
        [string]$Title
    )
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "   $Title" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
}

Export-ModuleMember -Function Write-Log, Write-Header
