# DevPush.ps1
# Helper script to fast-track the git commit & push cycle for VM testing
param([string]$Msg = "Update from Gemini CLI")

Write-Host "--- GIT STATUS ---" -ForegroundColor Cyan
git status -s

if ($LASTEXITCODE -ne 0) {
    Write-Host "Not a git repo or error occurred." -ForegroundColor Red
    exit
}

Write-Host "`n--- STAGING ALL CHANGES ---" -ForegroundColor Cyan
git add .

Write-Host "`n--- COMMITTING ('$Msg') ---" -ForegroundColor Cyan
git commit -m "$Msg"

Write-Host "`n--- PUSHING TO MAIN ---" -ForegroundColor Cyan
git push origin main

if ($?) {
    Write-Host "`n[SUCCESS] Code pushed. Ready to run on VM." -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Push failed." -ForegroundColor Red
}
