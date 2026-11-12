@echo off & cls & setlocal disabledelayedexpansion

set /a "count_replaced=0"
set /a "count_moved=0"

for /f "delims=" %%G in ('dir /b *" (1).mkv" 2^>nul') do call :ProcessCopy "%%G"
for /f "delims=" %%G in ('dir /b *.mkv 2^>nul') do call :SortFile "%%G"

for /d %%D in (*) do (
    if /i not "%%D"=="_Converted" if /i not "%%D"=="_Check" if /i not "%%D"=="_HEVC" (
        for %%F in ("%%D-*" "%%D.*") do (
            if exist "%%F" if not exist "%%F\" (
                if /i not "%%~xF"==".mkv" if /i not "%%~xF"==".mp4" if /i not "%%~xF"==".avi" if /i not "%%~xF"==".mov" if /i not "%%~xF"==".webm" if /i not "%%~xF"==".mpg" (
                    move /Y "%%F" "%%D\" >nul
                )
            )
        )
    )
)

echo.
echo =======================================
echo VERARBEITUNG ABGESCHLOSSEN
echo =======================================
echo Ersetzte Kopien: %count_replaced%
echo Verschobene Dateien: %count_moved%
echo =======================================
goto :END

:ProcessCopy
set "Kopie=%~1"
setlocal enabledelayedexpansion
set "Original=!Kopie: (1).mkv=.mkv!"
if exist "!Original!" del /f /q "!Original!"
ren "!Kopie!" "!Original!"
endlocal
set /a "count_replaced+=1"
goto :EOF

:SortFile
set "FullFile=%~1"
set "FileName=%~n1"
set "TargetDir="

setlocal enabledelayedexpansion
if "!FileName!" NEQ "!FileName: - S=!" (
    for /f "tokens=1,2 delims=@" %%A in ("!FileName: - S=@!") do (
        set "Rest=%%B"
        set "SNum=!Rest:~0,2!"
        
        set "isNumber=1"
        for /f "delims=0123456789" %%i in ("!SNum!") do set "isNumber=0"

        if "!isNumber!"=="1" (
            set "SName=%%A"
            if "!SNum!"=="00" (
                set "TDir=.\!SName!\Specials"
            ) else (
                set "SStripped=!SNum!"
                if "!SStripped:~0,1!"=="0" set "SStripped=!SStripped:~1!"
                set "TDir=.\!SName!\Staffel !SStripped!"
            )
            for /f "delims=" %%S in ("!TDir!") do (
                endlocal
                set "TargetDir=%%S"
            )
        ) else (
            endlocal
        )
    )
) else (
    endlocal
)

if "%TargetDir%"=="" (
    if /i "%FullFile%"=="%~nx0" goto :EOF
    set "TargetDir=%FileName%"
)

if not exist "%TargetDir%\" mkdir "%TargetDir%\"
move "%FileName%*" "%TargetDir%\" >nul
set /a "count_moved+=1"
goto :EOF

:END
endlocal
exit /b
