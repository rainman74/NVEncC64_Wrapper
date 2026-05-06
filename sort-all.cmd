@echo off & setlocal enabledelayedexpansion

:INIT
set "dp=%~dp0"

:MAIN
for %%I in (*.mkv *.mp4 *.mpg *.mov *.avi *.webm) do (
    call :PROCESS_FILE "%%I"
)
goto END

:PROCESS_FILE
set "VideoFile=%~1"
set "CheckMarkerFile=%~n1.checked"
set "NVEnc_Res="
set "NVEnc_Codec="
set "NVEnc_Crop=0:0:0:0"

if exist "!CheckMarkerFile!" exit /b

for /f "delims=" %%a in ('ffprobe -v error -select_streams v:0 -show_entries stream^=codec_name -of default^=noprint_wrappers^=1:nokey^=1 "%VideoFile%" 2^>nul') do (
    set "NVEnc_Codec=%%a"
)

if /I "!NVEnc_Codec!"=="hevc" (
    echo.
    echo Verschiebe HEVC: "%VideoFile%"
    if not exist "_HEVC" mkdir "_HEVC"
    move "%VideoFile%" "_HEVC\"
    exit /b
)

echo.
echo Verarbeite: "%VideoFile%" (Codec: !NVEnc_Codec!)
call run_probe.cmd "%VideoFile%"
echo.

if "!NVEnc_Res!"=="" (
    set "NVEnc_Res=_Check"
)

if not "!NVEnc_Crop!"=="0:0:0:0" (
    if not exist "!NVEnc_Res!" (
        mkdir "!NVEnc_Res!"
    )
    move "%VideoFile%" "!NVEnc_Res!\"
) else (
    type nul > "!CheckMarkerFile!"
    attrib +h "!CheckMarkerFile!"
)
exit /b

:END
endlocal
exit /b 0
