function Invoke-GitHubDownload {
    param(
        [string]$Token,
        [string]$User,
        [string]$Repo,
        [string]$Tag,
        [string]$DestDir
    )

    Write-Log "Connecting to GitHub API ($User/$Repo @ $Tag)..." "Cyan"

    try {
        $Headers = @{
            "Authorization" = "token $Token"
            "User-Agent"    = "PowerShell-Setup"
        }

        $ApiUrl = "https://api.github.com/repos/$User/$Repo/releases/tags/$Tag"
        $ReleaseData = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -UseBasicParsing
        
        if ($ReleaseData.assets.Count -gt 0) {
            Write-Log "Found $($ReleaseData.assets.Count) files." "Green"
            
            foreach ($asset in $ReleaseData.assets) {
                $FileName = $asset.name
                $ApiAssetUrl = $asset.url
                $LocalPath = Join-Path $DestDir $FileName
                
                if ($FileName -match "Source code") { continue }

                if (-not (Test-Path $LocalPath) -or (Get-Item $LocalPath).Length -eq 0) {
                    Write-Log "Downloading: $FileName..." "Yellow"
                    
                    try {
                        # S3 Redirect Fix
                        $Req = [System.Net.HttpWebRequest]::Create($ApiAssetUrl)
                        $Req.Method = "GET"
                        $Req.Accept = "application/octet-stream"
                        $Req.Headers.Add("Authorization", "token $Token")
                        $Req.UserAgent = "PowerShell-Setup"
                        $Req.AllowAutoRedirect = $false 
                        
                        try { $Resp = $Req.GetResponse() } catch { $Resp = $_.Exception.Response }

                        $RealDownloadUrl = $null
                        if ($Resp.StatusCode -eq [System.Net.HttpStatusCode]::Found -or $Resp.StatusCode -eq [System.Net.HttpStatusCode]::MovedPermanently) {
                            $RealDownloadUrl = $Resp.GetResponseHeader("Location")
                        }
                        $Resp.Close()

                        if ($RealDownloadUrl) {
                            $wc = New-Object System.Net.WebClient
                            $wc.DownloadFile($RealDownloadUrl, $LocalPath)
                            Write-Log "  -> Complete." "Gray"
                        } else {
                            Write-Log "  -> Failed to resolve S3 link." "Red"
                        }

                    } catch {
                        Write-Log "  -> Download Failed: $_" "Red"
                    }
                } else {
                    Write-Log "Skipping $FileName (Exists)." "Gray"
                }

                # Auto-Unzip
                if ($LocalPath.EndsWith(".zip")) {
                    Write-Log "  -> Unzipping archive..." "Cyan"
                    try {
                        Expand-Archive -Path $LocalPath -DestinationPath $DestDir -Force
                        Write-Log "  -> Extracted." "Green"
                    } catch {
                        Write-Log "  -> Extraction failed: $_" "Red"
                    }
                }
            }
        } else {
            Write-Log "WARNING: No files found in release '$Tag'!" "Red"
        }

    } catch {
        Write-Log "API ERROR: Could not fetch release info. $_" "Red"
    }
}

Export-ModuleMember -Function Invoke-GitHubDownload
