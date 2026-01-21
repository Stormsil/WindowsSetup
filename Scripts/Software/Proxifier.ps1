$Config = Get-SetupConfig
Install-Program -Name "Proxifier" -File "APP_Proxifier.exe" -InstallArgs $Config.SilentArgs -CheckPath "${env:ProgramFiles(x86)}\Proxifier\Proxifier.exe"
