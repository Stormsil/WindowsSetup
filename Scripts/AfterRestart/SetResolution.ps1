Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class DisplayTools {
    [DllImport("user32.dll")]
    public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);

    [DllImport("user32.dll")]
    public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [StructLayout(LayoutKind.Sequential)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }
}
"@

function Set-ScreenResolution {
    param (
        [int]$Width = 1920,
        [int]$Height = 1080
    )

    $devMode = New-Object DisplayTools+DEVMODE
    $devMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devMode)

    # 1. Try to find the exact mode we want (1920x1080, 32-bit, 60Hz)
    $modeNum = 0
    $found = $false
    
    while ([DisplayTools]::EnumDisplaySettings($null, $modeNum, [ref]$devMode)) {
        if ($devMode.dmPelsWidth -eq $Width -and 
            $devMode.dmPelsHeight -eq $Height -and 
            $devMode.dmBitsPerPel -eq 32 -and
            $devMode.dmDisplayFrequency -eq 60) {
            
            $found = $true
            break
        }
        $modeNum++
    }

    # 2. If exact match not found, try just Resolution
    if (-not $found) {
        $modeNum = 0
        while ([DisplayTools]::EnumDisplaySettings($null, $modeNum, [ref]$devMode)) {
            if ($devMode.dmPelsWidth -eq $Width -and $devMode.dmPelsHeight -eq $Height) {
                $found = $true
                break
            }
            $modeNum++
        }
    }

    if ($found) {
        # CDS_UPDATEREGISTRY = 0x01
        $result = [DisplayTools]::ChangeDisplaySettings([ref]$devMode, 1)
        
        switch ($result) {
            0 { Write-Host "Success: Resolution set to ${Width}x${Height}" -ForegroundColor Green }
            1 { Write-Host "Error: Restart required." -ForegroundColor Yellow }
            -2 { Write-Host "Error: Mode not supported." -ForegroundColor Red }
            default { Write-Host "Error: ChangeDisplaySettings failed code $result" -ForegroundColor Red }
        }
    } else {
        Write-Host "Error: The resolution ${Width}x${Height} is not supported by this monitor/driver." -ForegroundColor Red
        # List a few supported ones for debugging
        Write-Host "Supported modes sample:" -ForegroundColor Gray
        $devMode = New-Object DisplayTools+DEVMODE
        $devMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devMode)
        for ($i=0; $i -lt 5; $i++) {
            if ([DisplayTools]::EnumDisplaySettings($null, $i, [ref]$devMode)) {
                Write-Host "  - $($devMode.dmPelsWidth)x$($devMode.dmPelsHeight)" -ForegroundColor Gray
            }
        }
    }
}

Set-ScreenResolution -Width 1920 -Height 1080