$StatePath = "HKLM:\SOFTWARE\WindowsSetup\State"

function Test-Task {
    param([string]$TaskName)
    if (-not (Test-Path $StatePath)) { return $false }
    $val = Get-ItemProperty -Path $StatePath -Name $TaskName -ErrorAction SilentlyContinue
    return ($null -ne $val)
}

function Set-TaskComplete {
    param([string]$TaskName)
    if (-not (Test-Path $StatePath)) { New-Item -Path $StatePath -Force | Out-Null }
    New-ItemProperty -Path $StatePath -Name $TaskName -Value 1 -PropertyType DWord -Force | Out-Null
}

function Reset-State {
    if (Test-Path $StatePath) { Remove-Item -Path $StatePath -Recurse -Force }
}

Export-ModuleMember -Function Test-Task, Set-TaskComplete, Reset-State
