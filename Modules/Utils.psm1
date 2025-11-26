function Install-Program {
    param(
        [string]$Name,
        [string]$File,
        [string]$InstallArgs,
        [string]$WorkDir = $PSScriptRoot
    )

    # SetupDir is usually the parent of Scripts/Category, i.e. WindowsSetup/
    # But we can pass it or assume it. Let's assume files are in $Global:SetupDir which Main sets.
    $FilePath = Join-Path ${Global:SetupDir} $File

    if (Test-Path $FilePath) {
        Write-Log "Installing $Name..." "Cyan"
        try {
            $proc = Start-Process -FilePath $FilePath -ArgumentList $InstallArgs -Wait -PassThru -ErrorAction Stop
            if ($proc.ExitCode -eq 0) { 
                Write-Log "  -> Success." "Green" 
            }
            else { 
                Write-Log "  -> Finished with code $($proc.ExitCode)." "Gray" 
            }
        }
        catch { 
            Write-Log "  -> ERROR: $_" "Red" 
        }
    }
    else {
        Write-Log ("Skipping {0}: File not found ({1})." -f $Name, $File) "Gray"
    }
}

function Invoke-BatchFile {
    param(
        [string]$File
    )
    $FilePath = Join-Path ${Global:SetupDir} $File
    if (Test-Path $FilePath) {
        Write-Log "Running Batch: $File..." "Cyan"
        try {
            Start-Process -FilePath $FilePath -Verb RunAs -Wait
            Write-Log "  -> Complete." "Green"
        }
        catch {
            Write-Log "  -> Error: $_" "Red"
        }
    }
    else {
        Write-Log "Skipping Batch: File not found ($File)." "Gray"
    }
}

function Add-TrustedCertificate {
    param(
        [string]$File
    )
    $FilePath = Join-Path ${Global:SetupDir} $File
    if (Test-Path $FilePath) {
        try {
            $sig = Get-AuthenticodeSignature -FilePath $FilePath
            if ($sig.Status -ne "UnknownError" -and $sig.SignerCertificate) {
                $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "TrustedPublisher", "LocalMachine"
                $store.Open("ReadWrite")
                $store.Add($sig.SignerCertificate)
                $store.Close()
                Write-Log "  -> Certificate trusted for $File." "Green"
            }
        }
        catch {
            Write-Log "  -> Cert Error: $_" "Red"
        }
    }
}

function Test-Admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SetupConfig {
    $ConfigPath = Join-Path ${Global:SetupDir} "setup_config.json"
    if (Test-Path $ConfigPath) {
        return Get-Content $ConfigPath | ConvertFrom-Json
    }
    return $null
}

Export-ModuleMember -Function Install-Program, Invoke-BatchFile, Add-TrustedCertificate, Test-Admin, Get-SetupConfig
