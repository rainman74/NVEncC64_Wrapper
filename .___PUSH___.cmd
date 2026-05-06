@echo off & setlocal enabledelayedexpansion

:INIT
cd /d "%~dp0"
echo README.md > exclude.txt
echo .___CLAUDE___.cmd >> exclude.txt
echo .___PUSH___.cmd >> exclude.txt
xcopy "*.cmd" "%CMDPATH%\bin\" /y /exclude:exclude.txt
del exclude.txt

:MAIN
git add .
git commit -m "Updates" || echo No changes to commit.
git push

:END
timeout /t 3 >nul
exit /b
