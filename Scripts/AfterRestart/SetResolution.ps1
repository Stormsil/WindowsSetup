Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Display {
    [DllImport("user32.dll")]
    public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);

    [DllImport("user32.dll")]
    public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [StructLayout(LayoutKind.Sequential)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 0x20)]
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
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 0x20)]
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

function Set-Resolution {
    param (
        [int]$Width = 1920,
        [int]$Height = 1080
    )

    $devMode = New-Object Display+DEVMODE
    $devMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devMode)

    if ([Display]::EnumDisplaySettings($null, -1, [ref]$devMode)) {
        $devMode.dmPelsWidth = $Width
        $devMode.dmPelsHeight = $Height
        $devMode.dmFields = 0x80000 -bor 0x100000 # DM_PELSWIDTH | DM_PELSHEIGHT

        $result = [Display]::ChangeDisplaySettings([ref]$devMode, 0)
        if ($result -eq 0) {
            Write-Host "Resolution set to ${Width}x${Height}" -ForegroundColor Green
        } else {
            Write-Host "Failed to change resolution. Error code: $result" -ForegroundColor Red
        }
    } else {
        Write-Host "Failed to enumerate display settings." -ForegroundColor Red
    }
}

Set-Resolution -Width 1920 -Height 1080