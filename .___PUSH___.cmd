@echo off & setlocal enabledelayedexpansion

:INIT
cd /d "%~dp0"

:MAIN
git add .
git commit -m "Updates" || echo No changes to commit.
git push

:END
timeout /t 3 >nul
exit /b
