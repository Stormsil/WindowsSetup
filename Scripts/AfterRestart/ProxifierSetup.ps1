<#
    Proxy Setup Manager (Fixed)
    Changes:
    1. Forced Proxifier closure before every start.
    2. Increased delays for registry and process sync.
    3. Removed all Cyrillic and special characters for better compatibility.
#>

# --- CONFIGURATION ---
$Global:Config = @{
    ApiKey      = "kGOA6c0mqznmCmoCTEcacMON85hfgv1Z" # Your API Key
    Strictness  = 2
    ProcessName = "Proxifier"
}

# Path to Proxifier profile
$Global:ProfilePath = Join-Path $env:APPDATA "Proxifier4\Profiles\MyProxy.ppx"

function Show-Header {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor "DarkRed"
    Write-Host "       PROXY SETUP MANAGER (PS)          " -ForegroundColor "Red"
    Write-Host "=========================================" -ForegroundColor "DarkRed"
    Write-Host ""
}

function Stop-Proxifier {
    Write-Host "Checking running processes..." -ForegroundColor Yellow -NoNewline
    $process = Get-Process -Name $Global:Config.ProcessName -ErrorAction SilentlyContinue
    
    if ($process) {
        Write-Host " Stopping Proxifier..." -ForegroundColor Yellow
        Stop-Process -Name $Global:Config.ProcessName -Force -ErrorAction SilentlyContinue
        
        # Wait for the process to actually exit
        $waited = 0
        while ((Get-Process -Name $Global:Config.ProcessName -ErrorAction SilentlyContinue) -and ($waited -lt 10)) {
            Start-Sleep -Milliseconds 200
            $waited++
        }
        Write-Host " [OK] Proxifier closed" -ForegroundColor Green
    } else {
        Write-Host " Clean." -ForegroundColor Gray
    }
}

function Register-Proxifier {
    $LicenseKey = "5JZ6S-B3FKJ-49YYP-HCCQN-3JVHX"
    $RegPath = "HKCU:\SOFTWARE\Initex\Proxifier\License"

    Write-Host "Applying License..." -ForegroundColor Yellow

    try {
        if (-not (Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }

        New-ItemProperty -Path $RegPath -Name "Key" -Value $LicenseKey -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $RegPath -Name "Owner" -Value $LicenseKey -PropertyType String -Force | Out-Null

        Write-Host " [OK] License applied." -ForegroundColor Green
        
        Write-Host "Waiting 2 seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "Registry Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-PublicIP {
    param ($HostName)
    try {
        $HostName = $HostName.Trim()
        if ($HostName -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') { return $HostName }
        
        $ipObj = [System.Net.Dns]::GetHostAddresses($HostName)
        if ($ipObj -and $ipObj.Count -gt 0) {
            return $ipObj[0].IPAddressToString
        }
        return $null
    } catch { return $null }
}

function Check-Proxy {
    param ($ProxyInfo)
    Write-Host "Checking IPQS..." -ForegroundColor Yellow
    
    $ip = Get-PublicIP -HostName $ProxyInfo.Host
    if (-not $ip) {
        Write-Host "DNS Error for $($ProxyInfo.Host)" -ForegroundColor Red
        return 100
    }

    $url = "https://ipqualityscore.com/api/json/ip/$($Global:Config.ApiKey)/$ip`?strictness=$($Global:Config.Strictness)"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        
        Write-Host ""
        Write-Host "--- REPORT ($($ProxyInfo.Host)) ---" -ForegroundColor Cyan
        
        $scoreColor = "Red"
        if ($response.fraud_score -lt 10) { $scoreColor = "Green" }
        elseif ($response.fraud_score -lt 75) { $scoreColor = "Yellow" }

        Write-Host "Fraud Score: " -NoNewline; Write-Host $response.fraud_score -ForegroundColor $scoreColor
        Write-Host "Country:     $($response.country_code) - $($response.city)"
        
        function Show-Bool ($label, $val) {
            $c = if ($val) { "Red" } else { "Green" }
            $t = if ($val) { "Yes" } else { "No" }
            Write-Host "$($label): " -NoNewline; Write-Host $t -ForegroundColor $c
        }

        Show-Bool "Proxy" $response.proxy
        Show-Bool "VPN" $response.vpn
        Show-Bool "Blacklisted" $response.bot_status

        Write-Host "-------------------------------" -ForegroundColor Cyan
        return $response.fraud_score
    }
    catch {
        Write-Host "API Error: $($_.Exception.Message)" -ForegroundColor Red
        return 100
    }
}

function New-ProxifierProfile {
    param ($ProxyInfo)

    Stop-Proxifier

    Write-Host "Creating Profile..." -ForegroundColor Yellow
    
    try {
        $dir = Split-Path $Global:ProfilePath
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

        $xmlContent = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ProxifierProfile version="102" platform="Windows" product_id="0" product_minver="400">
    <Options>
        <Resolve>
            <AutoModeDetection enabled="false" />
            <ViaProxy enabled="true" />
            <BlockNonATypes enabled="true" />
            <ExclusionList OnlyFromListMode="false">%ComputerName%; localhost; *.local</ExclusionList>
            <DnsUdpMode>0</DnsUdpMode>
        </Resolve>
        <Encryption mode="disabled" />
        <ConnectionLoopDetection enabled="true" resolve="true" />
        <Udp mode="mode_block_all" />
        <LeakPreventionMode enabled="true" />
        <ProcessOtherUsers enabled="false" />
        <ProcessServices enabled="false" />
        <HandleDirectConnections enabled="false" />
        <HttpProxiesSupport enabled="false" />
    </Options>
    <ProxyList>
        <Proxy id="100" type="SOCKS5">
            <Authentication enabled="true">
                <Password>$($ProxyInfo.Password)</Password>
                <Username>$($ProxyInfo.Username)</Username>
            </Authentication>
            <Options>48</Options>
            <Port>$($ProxyInfo.Port)</Port>
            <Address>$($ProxyInfo.Host)</Address>
        </Proxy>
    </ProxyList>
    <ChainList />
    <RuleList>
        <Rule enabled="true">
            <Action type="Direct" />
            <Targets>localhost; 127.0.0.1; %ComputerName%; ::1</Targets>
            <Name>Localhost</Name>
        </Rule>
        <Rule enabled="true">
            <Action type="Proxy">100</Action>
            <Name>Default</Name>
        </Rule>
    </RuleList>
</ProxifierProfile>
"@

        Set-Content -Path $Global:ProfilePath -Value $xmlContent -Encoding UTF8
        Write-Host " [OK] Profile saved." -ForegroundColor Green
        
        Register-Proxifier

        Write-Host "Launching Proxifier..." -ForegroundColor Yellow
        Invoke-Item $Global:ProfilePath
        Start-Sleep -Seconds 1
        Write-Host " [OK] Done." -ForegroundColor Green
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- MAIN LOOP ---

Show-Header

while ($true) {
    Write-Host ""
    $inputStr = Read-Host "Enter proxy (HOST:PORT:USER:PASS) or 'exit'"
    
    if ($inputStr.Trim().ToLower() -eq "exit") { break }
    if ([string]::IsNullOrWhiteSpace($inputStr)) { continue }

    $parts = $inputStr.Split(':')
    if ($parts.Length -ne 4) {
        Write-Host "Format: HOST:PORT:USER:PASS" -ForegroundColor Red
        continue
    }

    $proxyInfo = @{
        Host     = $parts[0].Trim()
        Port     = $parts[1].Trim()
        Username = $parts[2].Trim()
        Password = $parts[3].Trim()
    }

    $score = Check-Proxy -ProxyInfo $proxyInfo

    if ($score -lt 30) {
        Write-Host "`n [OK] Good proxy. Setting up..." -ForegroundColor Green
        New-ProxifierProfile -ProxyInfo $proxyInfo
        break # Exit the loop after successful setup
    } else {
        Write-Host "`n [!] Fraud score $score. Skipping." -ForegroundColor Yellow
    }
}

Write-Host "Goodbye!" -ForegroundColor Green
Start-Sleep -Seconds 1