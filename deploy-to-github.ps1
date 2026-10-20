# PowerShell GitHub deployment helper for Smart Kirana Khata
$git = "C:\Users\error\AppData\Local\Programs\MinGit\cmd\git.exe"
$gh = "C:\Users\error\AppData\Local\Programs\gh\bin\gh.exe"

if (-not (Test-Path $git)) { $git = "git" }

Write-Host "=== Smart Kirana Khata Deployment ===" -ForegroundColor Green
Set-Location "C:\Users\error\.gemini\antigravity\scratch\smart-kirana-khata"

if (-not (Test-Path ".git")) {
    & $git init -b main
    Write-Host "Initialized git repository." -ForegroundColor Cyan
}

& $git add .
& $git commit -m "feat: complete Smart Kirana Khata upgrade with family khata, RLS & biometrics"

& $git remote remove origin 2>$null
& $git remote add origin https://github.com/kumaransh12050-png/smart-kirana-khata.git

Write-Host "Pushing to https://github.com/kumaransh12050-png/smart-kirana-khata.git..." -ForegroundColor Yellow
& $git push -u origin main
