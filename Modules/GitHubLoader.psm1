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

        # Fetch Release Info
        $ApiUrl = "https://api.github.com/repos/$User/$Repo/releases/tags/$Tag"
        $ReleaseData = Invoke-Retry -MaxAttempts 3 -DelaySeconds 2 -Action {
             Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -UseBasicParsing
        }
        
        if ($ReleaseData.assets.Count -gt 0) {
            Write-Log "Found $($ReleaseData.assets.Count) files." "Green"
            
            # Files to ignore (replaced by scripts)
            $IgnoreList = @("TOOL_KMS.exe", "TOOL_OOSU.exe", "Source code")

            foreach ($asset in $ReleaseData.assets) {
                $FileName = $asset.name
                $ApiAssetUrl = $asset.url
                $LocalPath = Join-Path $DestDir $FileName
                $TempPath = "$LocalPath.tmp"
                
                # Check Ignore List
                if ($IgnoreList | Where-Object { $FileName -match $_ }) { 
                    Write-Log "Skipping obsolete/ignored file: $FileName" "Gray"
                    continue 
                }

                # Integrity Check (Size)
                $ShouldDownload = $true
                if (Test-Path $LocalPath) {
                    $LocalSize = (Get-Item $LocalPath).Length
                    if ($LocalSize -eq $asset.size) {
                        Write-Log "Skipping $FileName (Verified: $($LocalSize) bytes)." "Green"
                        $ShouldDownload = $false
                    } else {
                        Write-Log "File mismatch: $FileName (Local: $LocalSize, Remote: $($asset.size)). Redownloading..." "Yellow"
                        Remove-Item $LocalPath -Force -ErrorAction SilentlyContinue
                    }
                }

                if ($ShouldDownload) {
                    Write-Log "Downloading: $FileName ($([math]::Round($asset.size / 1MB, 2)) MB)..." "Cyan"
                    
                    try {
                        # Resolve S3 Redirect (GitHub API quirks)
                        $RealDownloadUrl = Invoke-Retry -MaxAttempts 3 -Action {
                            $Req = [System.Net.HttpWebRequest]::Create($ApiAssetUrl)
                            $Req.Method = "GET"
                            $Req.Accept = "application/octet-stream"
                            $Req.Headers.Add("Authorization", "token $Token")
                            $Req.UserAgent = "PowerShell-Setup"
                            $Req.AllowAutoRedirect = $false 
                            
                            try { $Resp = $Req.GetResponse() } catch { $Resp = $_.Exception.Response }

                            if ($Resp.StatusCode -eq [System.Net.HttpStatusCode]::Found -or $Resp.StatusCode -eq [System.Net.HttpStatusCode]::MovedPermanently) {
                                return $Resp.GetResponseHeader("Location")
                            }
                            $Resp.Close()
                            return $null
                        }

                        if ($RealDownloadUrl) {
                            # Download to .tmp first (Atomic)
                            Invoke-Retry -MaxAttempts 3 -DelaySeconds 5 -Action {
                                $wc = New-Object System.Net.WebClient
                                $wc.DownloadFile($RealDownloadUrl, $TempPath)
                            }
                            
                            # Validate Size of Temp File
                            $TempSize = (Get-Item $TempPath).Length
                            if ($TempSize -eq $asset.size) {
                                Move-Item $TempPath -Destination $LocalPath -Force
                                Write-Log "  -> Complete." "Gray"
                            } else {
                                Remove-Item $TempPath -Force
                                throw "Downloaded file size mismatch ($TempSize vs $($asset.size))"
                            }
                        } else {
                            Write-Log "  -> Failed to resolve S3 link." "Red"
                        }

                    } catch {
                        Write-Log "  -> Download Failed: $_" "Red"
                        if (Test-Path $TempPath) { Remove-Item $TempPath -Force }
                    }
                }

                # Auto-Unzip
                if ($LocalPath.EndsWith(".zip") -and (Test-Path $LocalPath)) {
                    # Check if already extracted? (Simplification: just overwrite for now or rely on idempotent scripts)
                    Write-Log "  -> Unzipping archive..." "Cyan"
                    try {
                        Expand-Archive -Path $LocalPath -DestinationPath $DestDir -Force
                        Write-Log "  -> Extracted." "Green"
                    } catch {
                        Write-Log "  -> Extraction failed: $_" "Red"
                    }
                }
            }

            # ==============================================================================
            # CLEANUP / SYNC PHASE
            # ==============================================================================
            Write-Log "Syncing: Checking for obsolete files..." "Cyan"
            
            # 1. Build list of expected filenames from GitHub
            $ExpectedFiles = $ReleaseData.assets.name
            
            # 2. Get local files that look like assets (Safety filter to protect Scripts/Config)
            # Patterns based on your naming convention: APP_*, DRV_*, TOOL_*, SYS_*, DATA_*
            $LocalResources = Get-ChildItem -Path $DestDir -File | Where-Object { 
                $_.Name -match "^(APP|DRV|TOOL|SYS|DATA)_" 
            }

            foreach ($File in $LocalResources) {
                if ($File.Name -notin $ExpectedFiles) {
                    Write-Log "Deleting obsolete file: $($File.Name) (Not in GitHub Release)" "Yellow"
                    Remove-Item $File.FullName -Force -ErrorAction SilentlyContinue
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
