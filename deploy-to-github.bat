@echo off
echo ========================================================
echo   Smart Kirana Khata - GitHub Deployment Script
echo   Target: https://github.com/kumaransh12050-png/smart-kirana-khata
echo ========================================================
echo.

setlocal enabledelayedexpansion
set GIT_CMD=C:\Users\error\AppData\Local\Programs\MinGit\cmd\git.exe
set GH_CMD=C:\Users\error\AppData\Local\Programs\gh\bin\gh.exe

if not exist "!GIT_CMD!" (
    set GIT_CMD=git
)

echo [1/4] Checking Git repository initialization...
if not exist ".git" (
    "!GIT_CMD!" init -b main
    echo Git repository initialized on branch main.
) else (
    echo Git repository already exists.
)

echo.
echo [2/4] Staging and committing all project files...
"!GIT_CMD!" add .
"!GIT_CMD!" commit -m "feat: complete Smart Kirana Khata enterprise ledger with family khata, RLS & biometrics"

echo.
echo [3/4] Configuring remote origin...
"!GIT_CMD!" remote remove origin 2>nul
"!GIT_CMD!" remote add origin https://github.com/kumaransh12050-png/smart-kirana-khata.git

echo.
echo [4/4] Pushing to GitHub...
echo To push, make sure you are logged in to GitHub:
echo Option A: Run 'gh auth login' in terminal
echo Option B: Enter your GitHub Personal Access Token when prompted by Git.
echo.

"!GIT_CMD!" push -u origin main

if errorlevel 1 (
    echo.
    echo ----------------------------------------------------------------------
    echo Push could not complete automatically because GitHub credentials are required.
    echo Please run:
    echo    gh auth login
    echo Or create the repository at https://github.com/new named 'smart-kirana-khata'
    echo and push with your personal token.
    echo ----------------------------------------------------------------------
) else (
    echo.
    echo ========================================================
    echo  SUCCESS! Deployed to GitHub.
    echo  Repo: https://github.com/kumaransh12050-png/smart-kirana-khata
    echo ========================================================
)

pause
