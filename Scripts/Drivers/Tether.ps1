Add-TrustedCertificate -CertFile "DRV_Tether.exe"
$Config = Get-SetupConfig
Install-Program -Name "Tether Driver" -File "DRV_Tether.exe" -InstallArgs $Config.SilentArgs
