@echo off
set "PATH=%PATH%;C:\Users\error\AppData\Local\Programs\MinGit\cmd"
cd /d "C:\Users\error\.gemini\antigravity\scratch\smart-kirana-khata"

echo ========================================================
echo   Smart Kirana Khata - Instant GitHub Push
echo ========================================================
echo.
set /p GHP_TOKEN="Right-click and paste your GitHub token (ghp_...), then press Enter: "

echo.
echo Pushing files to https://github.com/kumaransh12050-png/smart-kirana-khata.git...
git push https://kumaransh12050-png:%GHP_TOKEN%@github.com/kumaransh12050-png/smart-kirana-khata.git main

echo.
if errorlevel 1 (
    echo [ERROR] Push failed. Please verify the token.
) else (
    echo [SUCCESS] All files are now live on your GitHub!
    echo Visit: https://github.com/kumaransh12050-png/smart-kirana-khata
)

echo.
pause
