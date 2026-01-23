function Get-StateFilePath {
    if ($Global:SetupDir) {
        # Store state in the PARENT directory of the repo (e.g., C:\WindowsSetup\)
        # This allows the repo folder (C:\WindowsSetup\System) to be wiped/updated without losing state.
        return Join-Path (Split-Path $Global:SetupDir -Parent) ".setup_state.json"
    }
    # Fallback for testing/undefined
    return Join-Path $PSScriptRoot "..\..\.setup_state.json"
}

function Get-State {
    $path = Get-StateFilePath
    if (Test-Path $path) {
        try {
            $json = Get-Content -Path $path -Raw
            if ([string]::IsNullOrWhiteSpace($json)) { return @{} }
            
            $obj = $json | ConvertFrom-Json
            
            # Convert PSCustomObject to Hashtable for PS 5.1 compatibility
            $hash = @{}
            if ($obj) {
                $obj.PSObject.Properties | ForEach-Object {
                    $hash[$_.Name] = $_.Value
                }
            }
            return $hash
        } catch {
            return @{}
        }
    }
    return @{}
}

function Save-State {
    param($State)
    $path = Get-StateFilePath
    $State | ConvertTo-Json -Depth 2 | Set-Content -Path $path -Force
}

function Test-Task {
    param([string]$TaskName)
    $State = Get-State
    return ($State.ContainsKey($TaskName) -and $State[$TaskName] -eq $true)
}

function Set-TaskComplete {
    param([string]$TaskName)
    $State = Get-State
    $State[$TaskName] = $true
    Save-State -State $State
}

function Reset-State {
    $path = Get-StateFilePath
    if (Test-Path $path) { Remove-Item -Path $path -Force }
}

Export-ModuleMember -Function Test-Task, Set-TaskComplete, Reset-State
