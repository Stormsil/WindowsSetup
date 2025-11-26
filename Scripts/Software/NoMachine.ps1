$Config = Get-SetupConfig
Install-Program -Name "NoMachine" -File "APP_Nomachine.exe" -InstallArgs $Config.SilentArgs
