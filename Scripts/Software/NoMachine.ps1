$Config = Get-SetupConfig
Install-Program -Name "NoMachine" -File "APP_Nomachine.exe" -InstallArgs $Config.SilentArgs -CheckPath "${env:ProgramFiles(x86)}\NoMachine\bin\nxplayer.exe"
