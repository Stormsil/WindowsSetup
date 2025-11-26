$Config = Get-SetupConfig
Install-Program -Name "TSM Application" -File "APP_TSM.exe" -InstallArgs $Config.SilentArgs
