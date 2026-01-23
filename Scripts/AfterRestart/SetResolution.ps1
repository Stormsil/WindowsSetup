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

    Write-Host "Attempting to set resolution to ${Width}x${Height}..." -ForegroundColor Cyan

    # 1. Get Current Settings to populate the struct basics (Device Name, etc.)
    # -1 = ENUM_CURRENT_SETTINGS
    if ([DisplayTools]::EnumDisplaySettings($null, -1, [ref]$devMode)) {
        
        Write-Host "Current Resolution: $($devMode.dmPelsWidth)x$($devMode.dmPelsHeight)" -ForegroundColor Gray

        # 2. Modify just the resolution fields
        $devMode.dmPelsWidth = $Width
        $devMode.dmPelsHeight = $Height
        
        # DM_PELSWIDTH (0x80000) | DM_PELSHEIGHT (0x100000)
        $devMode.dmFields = 0x80000 -bor 0x100000 

        # 3. Apply
        # CDS_UPDATEREGISTRY = 0x01
        $result = [DisplayTools]::ChangeDisplaySettings([ref]$devMode, 0)
        
        switch ($result) {
            0 { Write-Host "Success: Resolution set to ${Width}x${Height}" -ForegroundColor Green }
            1 { Write-Host "Error: Restart required." -ForegroundColor Yellow }
            -2 { Write-Host "Error: Mode not supported (Try checking Refresh Rate)." -ForegroundColor Red }
            default { Write-Host "Error: ChangeDisplaySettings failed code $result" -ForegroundColor Red }
        }
    } else {
        Write-Host "CRITICAL ERROR: Failed to enumerate CURRENT display settings." -ForegroundColor Red
        Write-Host "This usually means the P/Invoke struct is mismatched or no display driver is active." -ForegroundColor Red
        
        # Fallback: Try to list what IS supported
        Write-Host "`nListing first 5 available modes (Index 0-4):" -ForegroundColor Gray
        for ($i = 0; $i -lt 5; $i++) {
            $dm = New-Object DisplayTools+DEVMODE
            $dm.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($dm)
            if ([DisplayTools]::EnumDisplaySettings($null, $i, [ref]$dm)) {
                Write-Host "  [$i] $($dm.dmPelsWidth)x$($dm.dmPelsHeight) @ $($dm.dmDisplayFrequency)Hz" -ForegroundColor Gray
            } else {
                 Write-Host "  [$i] Enum failed." -ForegroundColor DarkGray
            }
        }
    }
}

Set-ScreenResolution -Width 1920 -Height 1080