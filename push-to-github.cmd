@echo off
title Smart Kirana Khata - GitHub Push
color 0A

echo ===================================================================
echo   SMART KIRANA KHATA - AUTOMATED GIT EXECUTION
echo   Target: https://github.com/kumaransh12050-png/smart-kirana-khata
echo ===================================================================
echo.

:: 1. Ensure git and gh are in PATH
set "PATH=%PATH%;C:\Users\error\AppData\Local\Programs\MinGit\cmd;C:\Users\error\AppData\Local\Programs\gh\bin"

:: 2. Change to project directory
cd /d "C:\Users\error\.gemini\antigravity\scratch\smart-kirana-khata"

echo [1/5] Verifying Git Installation...
git --version
if errorlevel 1 (
    echo ERROR: Git is not available.
    pause
    exit /b 1
)

echo.
echo [2/5] Configuring Git User Identity...
git config user.name "Ansh raj"
git config user.email "kumaransh12050@users.noreply.github.com"
echo Configured: Ansh raj (kumaransh12050-png)

echo.
echo [3/5] Staging All Files in Git...
git add -A
git status --short

echo.
echo [4/5] Creating Git Commit...
git commit -m "feat: complete Smart Kirana Khata digital ledger with family khata, RLS & biometrics"

echo.
echo [5/5] Setting Remote Repository & Pushing to GitHub...
git remote remove origin 2>nul
git remote add origin https://github.com/kumaransh12050-png/smart-kirana-khata.git
git branch -M main

echo.
echo Pushing branch 'main' to https://github.com/kumaransh12050-png/smart-kirana-khata.git...
echo.
echo (NOTE: If prompted for Password, paste your GitHub Personal Access Token)
echo (Or complete the browser sign-in window if it appears)
echo.

git push -u origin main

if errorlevel 1 (
    echo.
    echo ===================================================================
    echo PUSH REQUIRES GITHUB AUTHENTICATION:
    echo 1. Generate a token at: https://github.com/settings/tokens
    echo    (Check 'repo' checkbox, click 'Generate token')
    echo 2. Run this command in CMD:
    echo    git push https://YOUR_TOKEN@github.com/kumaransh12050-png/smart-kirana-khata.git main
    echo ===================================================================
) else (
    echo.
    echo ===================================================================
    echo SUCCESS! All files have been pushed to your GitHub repository:
    echo https://github.com/kumaransh12050-png/smart-kirana-khata
    echo ===================================================================
)

echo.
pause
