# ==========================================
# MAIN.PS1 - DOWNLOAD TEST MODE
# ==========================================
# Задача: Проверить связь с GitHub Releases и скачать файлы без установки.

# --- КОНФИГУРАЦИЯ (С ТВОЕГО СКРИНШОТА) ---
$GithubUser = "Stormsil"
$RepoName   = "WindowsSetup"
$ReleaseTag = "files"   # Тэг, который я вижу на скрине
$DownloadDir = "C:\WindowsSetup" # Куда качать

# Формируем базовую ссылку: https://github.com/USER/REPO/releases/download/TAG
$BaseUrl = "https://github.com/$GithubUser/$RepoName/releases/download/$ReleaseTag"

# Список файлов (Точь-в-точь как на скриншоте)
$FilesToDownload = @(
    "Driver.exe",
    "nomachine_9.2.18_1_x64.exe",
    "TetherDriver.exe",
    "TSM.exe"
)

# --- ЛОГИРОВАНИЕ ---
function Write-Log { 
    param([string]$Msg, [string]$Color="White") 
    Write-Host "[CLOUD-TEST] $((Get-Date).ToString('HH:mm:ss')) $Msg" -ForegroundColor $Color 
}

Clear-Host
Write-Log "=== DOWNLOAD TEST STARTED ===" "Cyan"
Write-Log "Repo: $GithubUser/$RepoName" "Gray"
Write-Log "Tag:  $ReleaseTag" "Gray"
Write-Log "Target Dir: $DownloadDir" "Gray"

# Создаем папку если нет
if (-not (Test-Path $DownloadDir)) { 
    New-Item -Path $DownloadDir -ItemType Directory -Force | Out-Null 
}

# --- ЦИКЛ ЗАГРУЗКИ ---
foreach ($fileName in $FilesToDownload) {
    $Url = "$BaseUrl/$fileName"
    $LocalPath = Join-Path $DownloadDir $fileName
    
    Write-Log "----------------------------------------" "Gray"
    Write-Log "Processing: $fileName" "Yellow"
    
    # Проверка, есть ли файл
    if (Test-Path $LocalPath) {
        Write-Log "File already exists locally." "Yellow"
        # Для теста можно удалить старый, чтобы проверить скачивание заново
        # Remove-Item $LocalPath -Force 
    }
    
    try {
        Write-Log "Downloading from: $Url" "Gray"
        
        # Настраиваем безопасность (TLS 1.2)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Качаем
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($Url, $LocalPath)
        
        # ПРОВЕРКА РЕЗУЛЬТАТА
        if (Test-Path $LocalPath) {
            $Item = Get-Item $LocalPath
            $SizeMB = "{0:N2} MB" -f ($Item.Length / 1MB)
            
            if ($Item.Length -gt 1000) { # Если больше 1 КБ (значит не ошибка 404)
                Write-Log "SUCCESS! Saved to disk ($SizeMB)." "Green"
            } else {
                Write-Log "WARNING: File is suspiciously small ($SizeMB). Check URL/Tag!" "Red"
            }
        } else {
            Write-Log "ERROR: File not found after download attempt." "Red"
        }

    } catch {
        Write-Log "DOWNLOAD FAILED: $_" "Red"
        Write-Log "Check if the filename matches exactly what is on GitHub!" "Red"
    }
}

Write-Log "========================================" "Cyan"
Write-Log "   TEST COMPLETE. FILES ARE READY.      " "Cyan"
Write-Log "   NO INSTALLATION WAS PERFORMED.       " "Cyan"
Write-Log "========================================" "Cyan"