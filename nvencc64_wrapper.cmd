@echo off & setlocal enabledelayedexpansion

:INIT
call :SETESC
call :SETTOKEN

set "VFX_MODEL_DIR=%NVVFX_MODEL_DIR%"
set "ONNX_MODEL_DIR=%CMDPATH%\bin\onnx_models"
set "NV_FLAGS=--vpp-onnx-model-dir "%ONNX_MODEL_DIR%" --vpp-nvvfx-model-dir "%VFX_MODEL_DIR%""

if '%1'=='-h' goto USAGE
if '%1'=='' goto USAGE

set "EDIT_TAGS=1"
set "DEBUG=0"
if "%DEBUG%"=="1" (set "DBG=call :DEBUG") else (set "DBG=call :NOP")

call :VALIDATE-PARAMS %*
if "!PARAM_ERR!"=="1" goto :END

call :SETENCODER %1 %2 %3 %4 %5 %6 %7 %8
call :SETAUDIO	 %1 %2 %3 %4 %5 %6 %7 %8
call :SETCROP	 %1 %2 %3 %4 %5 %6 %7 %8
call :SETFILTER	 %1 %2 %3 %4 %5 %6 %7 %8
set "FILTER_HAS_RESIZE=0"
if defined FILTER (
	echo(!FILTER! | findstr /i /c:"--vpp-resize" >nul && set "FILTER_HAS_RESIZE=1"
)
call :SETMODE	 %1 %2 %3 %4 %5 %6 %7 %8
if defined MODE (
	echo(!MODE! | findstr /i /c:"--vpp-resize" >nul && set "FILTER_HAS_RESIZE=1"
)
call :SETDECODER %1 %2 %3 %4 %5 %6 %7 %8
call :SETCHKENC  %1 %2 %3 %4 %5 %6 %7 %8
set "DECODER_PARAM="
if defined DECODER set "DECODER_PARAM=--%DECODER%"

set "REQ_Q=%3"
if "!REQ_Q!"=="" set "REQ_Q=def"

call :MAIN
goto :END

:SETQUALITY-HEVC
set "ACTUAL_Q=!REQ_Q!"
set "AUTO_Q_FALLBACK=0"
if "!REQ_Q!"=="auto" (
	set "ACTUAL_Q=none"
	echo "!FILENAME!" | findstr /c:"(19" >nul && set "ACTUAL_Q=hq"
	echo "!FILENAME!" | findstr /c:"(20" >nul && set "ACTUAL_Q=def"
	if "!ACTUAL_Q!"=="none" (set "ACTUAL_Q=def" & set "AUTO_Q_FALLBACK=1")
)
set "PRESET=--preset p7"
set "B_REF=--bframes 3 --ref 4"
if "!ACTUAL_Q!"=="uhq"		(set "QUALITY=24" & set "TUNING=--tune uhq --multipass 2pass-full" & set "B_REF=--bframes 4 --ref 4")
if "!ACTUAL_Q!"=="hq"		(set "QUALITY=26" & set "TUNING=--tune hq  --multipass 2pass-quarter")
if "!ACTUAL_Q!"=="def"		(set "QUALITY=28" & set "TUNING=--tune hq  --multipass none")
if "!ACTUAL_Q!"=="lq"		(set "QUALITY=30" & set "TUNING=--tune lowlatency --multipass none")
if "!ACTUAL_Q!"=="ulq"		(set "QUALITY=32" & set "TUNING=--tune ultralowlatency --multipass none" & set "PRESET=--preset p1")
exit /b

:SETQUALITY-H264
set "ACTUAL_Q=!REQ_Q!"
set "AUTO_Q_FALLBACK=0"
if "!REQ_Q!"=="auto" (
	set "ACTUAL_Q=none"
	echo "!FILENAME!" | findstr /c:"(19" >nul && set "ACTUAL_Q=hq"
	echo "!FILENAME!" | findstr /c:"(20" >nul && set "ACTUAL_Q=def"
	if "!ACTUAL_Q!"=="none" (set "ACTUAL_Q=def" & set "AUTO_Q_FALLBACK=1")
)
set "PRESET=--preset p7"
set "B_REF=--bframes 3 --ref 4"
if "!ACTUAL_Q!"=="uhq"		(set "QUALITY=20" & set "TUNING=--tune hq --multipass 2pass-full" & set "B_REF=--bframes 4 --ref 4")
if "!ACTUAL_Q!"=="hq"		(set "QUALITY=22" & set "TUNING=--tune hq --multipass 2pass-quarter")
if "!ACTUAL_Q!"=="def"		(set "QUALITY=24" & set "TUNING=--tune hq --multipass none")
if "!ACTUAL_Q!"=="lq"		(set "QUALITY=26" & set "TUNING=--tune lowlatency --multipass none")
if "!ACTUAL_Q!"=="ulq"		(set "QUALITY=28" & set "TUNING=--tune ultralowlatency --multipass none" & set "PRESET=--preset p1")
exit /b

:SETENCODER
set "ENCODER=hevc" & set "PROFILE=main"
if "%1"=="def"				(set "ENCODER=hevc" & set "PROFILE=main")
if "%1"=="hevc"				(set "ENCODER=hevc" & set "PROFILE=main")
if "%1"=="he10"				(set "ENCODER=hevc" & set "PROFILE=main10 --output-depth 10")
if "%1"=="h264"				(set "ENCODER=h264" & set "PROFILE=high")
if "%1"=="av1"				(set "ENCODER=av1"	& set "PROFILE=high")
exit /b

:SETAUDIO
set "AUDIO=--audio-codec ac3 --audio-bitrate stereo:192,5.1:384 --audio-encode-other-codec-only --audio-stream 7.1:5.1"
if "%2"=="copy"				(set "AUDIO=--audio-copy")
if "%2"=="copy1"			(set "AUDIO=--audio-copy 1")
if "%2"=="copy2"			(set "AUDIO=--audio-copy 2")
if "%2"=="copy12"			(set "AUDIO=--audio-copy 1,2")
if "%2"=="copy23"			(set "AUDIO=--audio-copy 2,3")
if "%2"=="ac3"				(set "AUDIO=--audio-codec ac3 --audio-bitrate stereo:192,5.1:384 --audio-encode-other-codec-only --audio-stream 7.1:5.1")
if "%2"=="aac"				(set "AUDIO=--audio-codec aac --audio-bitrate stereo:128,5.1:256 --audio-encode-other-codec-only")
if "%2"=="eac3"				(set "AUDIO=--audio-codec eac3 --audio-bitrate stereo:320,5.1:640 --audio-encode-other-codec-only")
exit /b

:SETCROP
set "CROP=" & set "CROP_MODE="
if /i "%4"=="auto" (
	set "CROP_MODE=AUTO"
	exit /b
)
if "%4"=="none"				(set "CROP=")
if "%4"=="43"				(set "CROP=--crop 0,0,0,0 --output-res 720x540")
if "%4"=="169"				(set "CROP=--crop 0,0,0,0 --output-res 960x540")
if "%4"=="696"				(set "CROP=--crop 0,192,0,192")
if "%4"=="752"				(set "CROP=--crop 0,164,0,164")
if "%4"=="768"				(set "CROP=--crop 0,156,0,156")
if "%4"=="800"				(set "CROP=--crop 0,140,0,140")
if "%4"=="804"				(set "CROP=--crop 0,138,0,138")
if "%4"=="808"				(set "CROP=--crop 0,136,0,136")
if "%4"=="812"				(set "CROP=--crop 0,134,0,134")
if "%4"=="816"				(set "CROP=--crop 0,132,0,132")
if "%4"=="872"				(set "CROP=--crop 0,104,0,104")
if "%4"=="960"				(set "CROP=--crop 0,60,0,60")
if "%4"=="1012"				(set "CROP=--crop 0,34,0,34")
if "%4"=="1024"				(set "CROP=--crop 0,28,0,28")
if "%4"=="1036"				(set "CROP=--crop 0,22,0,22")
if "%4"=="1040"				(set "CROP=--crop 0,20,0,20")
if "%4"=="720"				(set "CROP=--crop 60,0,60,0 --output-res 1280x-2")
if "%4"=="720p"				(set "CROP=--crop 64,0,64,0 --output-res -2x720")
if "%4"=="720f"				(set "CROP=--crop 66,0,66,0 --output-res 1280x720")
if "%4"=="1080"				(set "CROP=--crop 70,0,70,0 --output-res 1920x-2")
if "%4"=="1080p"			(set "CROP=--crop 78,0,78,0 --output-res -2x1080")
if "%4"=="1080f"			(set "CROP=--crop 150,0,150,0 --output-res 1920x1080")
if "%4"=="2160"				(set "CROP=--crop 210,0,210,0 --output-res 3840x-2")
if "%4"=="2160p"			(set "CROP=--crop 220,0,220,0 --output-res -2x2160")
if "%4"=="2160f"			(set "CROP=--crop 250,0,250,0 --output-res 3840x2160")
if "%4"=="1440"				(set "CROP=--crop 286,0,286,0 --output-res 1440x1080")
if "%4"=="1348"				(set "CROP=--crop 240,0,240,0 --output-res 1348x1080")
if "%4"=="1408"				(set "CROP=--crop 0,0,0,0 --output-res 1408x1080")
if "%4"=="1420"				(set "CROP=--crop 0,0,0,0 --output-res 1420x1080")
if "%4"=="1480"				(set "CROP=--crop 0,0,0,0 --output-res 1480x1080")
if "%4"=="1500"				(set "CROP=--crop 0,0,0,0 --output-res 1500x1080")
if "%4"=="1620"				(set "CROP=--crop 0,0,0,0 --output-res 1620x1080")
if "%4"=="1764"				(set "CROP=--crop 0,0,0,0 --output-res 1764x1080")
if "%4"=="1780"				(set "CROP=--crop 0,0,0,0 --output-res 1780x1080")
if "%4"=="1788"				(set "CROP=--crop 0,0,0,0 --output-res 1788x1080")
if "%4"=="1792"				(set "CROP=--crop 0,0,0,0 --output-res 1792x1080")
if "%4"=="1800"				(set "CROP=--crop 0,0,0,0 --output-res 1800x1080")
if "%4"=="c1"				(set "CROP=")
if "%4"=="c2"				(set "CROP=")
if "%4"=="c3"				(set "CROP=")
if "%4"=="c4"				(set "CROP=")
if "%4"=="c5"				(set "CROP=")
if "%4"=="c6"				(set "CROP=")
exit /b

:SETFILTER
set "FILTER="
if "%5"=="none"				(set "FILTER=")
if "%5"=="edgelevel"		(set "FILTER=--vpp-edgelevel --vpp-detailsharpen")
if "%5"=="smooth"			(set "FILTER=--vpp-msmooth")
if "%5"=="smoothlq"		    (set "FILTER=--vpp-msmooth strength=1,threshold=15.0")
if "%5"=="smoothhq"			(set "FILTER=--vpp-msmooth strength=6,threshold=30.0")
if "%5"=="nlmeans"			(set "FILTER=--vpp-nlmeans sigma=0.002,h=0.008,patch=5,search=7,d=2,search_t=7 --vpp-unsharp radius=3,weight=0.25")
if "%5"=="gauss"			(set "FILTER=--vpp-gauss 3")
if "%5"=="gauss5"			(set "FILTER=--vpp-gauss 5")
if "%5"=="sharp"			(set "FILTER=--vpp-msharpen strength=1.0,threshold=15.0")
if "%5"=="denoise"			(set "FILTER=--vpp-nvvfx-denoise strength=0")
if "%5"=="denoisehq"		(set "FILTER=--vpp-nvvfx-denoise strength=1")
if "%5"=="artifact"			(set "FILTER=--vpp-nvvfx-artifact-reduction mode=0")
if "%5"=="artifacthq"		(set "FILTER=--vpp-nvvfx-artifact-reduction mode=1")
if "%5"=="superres"			(set "FILTER=--vpp-resize algo=nvvfx-superres,superres-mode=0,superres-strength=0.4")
if "%5"=="superreshq"		(set "FILTER=--vpp-resize algo=nvvfx-superres,superres-mode=1,superres-strength=0.4")
if "%5"=="vsr"				(set "FILTER=--vpp-resize algo=ngx-vsr,vsr-quality=4")
if "%5"=="vsrdenoise"		(set "FILTER=--vpp-resize algo=ngx-vsr,vsr-quality=4 --vpp-nvvfx-denoise strength=0")
if "%5"=="vsrdenoisehq"		(set "FILTER=--vpp-resize algo=ngx-vsr,vsr-quality=4 --vpp-nvvfx-denoise strength=1")
if "%5"=="vsrartifact"		(set "FILTER=--vpp-resize algo=ngx-vsr,vsr-quality=4 --vpp-nvvfx-artifact-reduction mode=0")
if "%5"=="vsrartifacthq"	(set "FILTER=--vpp-resize algo=ngx-vsr,vsr-quality=4 --vpp-nvvfx-artifact-reduction mode=1")
if "%5"=="dehalo"	        (set "FILTER=--vpp-finedehalo rx=3.0,ry=3.0")
if "%5"=="dehalo2"	        (set "FILTER=--vpp-finedehalo rx=2.0,ry=2.0")
if "%5"=="log"				(set "FILTER=--log-packets input_packets.log")
if "%5"=="f1"				(set "FILTER=")
if "%5"=="f2"				(set "FILTER=")
if "%5"=="f3"				(set "FILTER=")
if "%5"=="f4"				(set "FILTER=")
if "%5"=="f5"				(set "FILTER=")
if "%5"=="f6"				(set "FILTER=")
exit /b

:SETMODE
set "MODE="
if "%6"=="none"				(set "MODE=")
if "%6"=="deint"			(set "MODE=--interlace auto --vpp-deinterlace adaptive")
if "%6"=="ivtc"				(set "MODE=--vpp-ivtc --vpp-decimate")
if "%6"=="rtgmc"			(set "MODE=--vpp-rtgmc preset=slower,input_type=0,source_match=3,lossless=2")
if "%6"=="rtgmcp"			(set "MODE=--vpp-rtgmc preset=slower,input_type=1,source_match=3,lossless=0")
if "%6"=="double"			(set "MODE=--vpp-fruc double")
if "%6"=="23fps"			(set "MODE=--fps 24000/1001")
if "%6"=="25fps"			(set "MODE=--fps 25.0")
if "%6"=="30fps"			(set "MODE=--fps 30.0")
if "%6"=="60fps"			(set "MODE=--fps 60.0")
if "%6"=="29fps"			(set "MODE=--fps 30000/1001")
if "%6"=="59fps"			(set "MODE=--fps 60000/1001")
if "%6"=="tweak"			(set "MODE=--vpp-tweak brightness=-0.01,contrast=1.03,gamma=1.0,saturation=1.0,hue=0.0")
if "%6"=="lighter"			(set "MODE=--vpp-curves preset=lighter")
if "%6"=="darker"			(set "MODE=--vpp-curves preset=darker")
if "%6"=="vintage"			(set "MODE=--vpp-curves preset=vintage")
if "%6"=="linear"			(set "MODE=--vpp-curves green=0/0 0.5/0.5 1/1:red=0/0 0.5/0.5 1/1:blue=0/0 0.5/0.5 1/1")
if "%6"=="HDRtoSDR"			(set "MODE=--vpp-colorspace matrix=bt2020nc:bt709,colorprim=bt2020:bt709,transfer=smpte2084:bt709,range=auto:auto,hdr2sdr=bt2390")
if "%6"=="HDRtoSDRR"		(set "MODE=--vpp-colorspace matrix=bt2020nc:bt709,colorprim=bt2020:bt709,transfer=smpte2084:bt709,range=auto:auto,hdr2sdr=reinhard")
if "%6"=="HDRtoSDRM"		(set "MODE=--vpp-colorspace matrix=bt2020nc:bt709,colorprim=bt2020:bt709,transfer=smpte2084:bt709,range=auto:auto,hdr2sdr=mobius")
if "%6"=="HDRtoSDRH"		(set "MODE=--vpp-colorspace matrix=bt2020nc:bt709,colorprim=bt2020:bt709,transfer=smpte2084:bt709,range=auto:auto,hdr2sdr=hable")
if "%6"=="dv"				(set "MODE=--dolby-vision-profile copy --dolby-vision-rpu copy --master-display copy --max-cll copy")
if "%6"=="dolby-vision"		(set "MODE=--dolby-vision-profile copy --dolby-vision-rpu copy --master-display copy --max-cll copy")
exit /b

:SETDECODER
set "DECODER=avhw"
if "%7"=="def"				(set "DECODER=avhw")
if "%7"=="hw"				(set "DECODER=avhw")
if "%7"=="sw"				(set "DECODER=avsw")
if "%7"=="auto"				(set "DECODER=")
exit /b

:SETCHKENC
set "CHECK_ENCODED=1"
if "%8"=="def"				(set "CHECK_ENCODED=1")
if "%8"=="true"				(set "CHECK_ENCODED=1")
if "%8"=="false"			(set "CHECK_ENCODED=0")
exit /b

:MAIN
call :ENSURE_DIR "_Converted"
set "FOUND=0"
setlocal DisableDelayedExpansion
for %%I in (*.mkv *.mp4 *.mpg *.mov *.avi *.webm) do if exist "%%I" if not exist "_Converted\%%~nI.mkv" (
	echo %ESC%[101;93m %%I %ESC%[0m

	set "FOUND=1"
	set "FILENAME=%%~nI"
	set "INFILE=%%I"
	set "INBASE=%%~nI"
	set "INNAME=%%~nxI"
	set "INDIR=%%~dpI"
	set "SKIP_FILE="
	set "RESIZE_PARAM="
	set "CROP_L=0"
	set "CROP_R=0"
	set "TARGET_DIR="
	set "RESIZE_REQUIRED=0"
	set "SRC_CODEC="

	setlocal EnableDelayedExpansion

	for /f "usebackq delims=" %%C in (`mediainfo "--Inform=Video;%%Format%%" "!INFILE!"`) do (
		set "SRC_CODEC=%%C"
	)

	if not defined SRC_CODEC (
		echo ERROR: Could not detect codec. Moving file to _Check.
		call :ENSURE_DIR "_Check"
		move /Y "!INFILE!" "_Check\" >nul
		set "SKIP_FILE=1"
	) else (
		if "%CHECK_ENCODED%"=="1" (
			if /i "!SRC_CODEC!"=="HEVC" if /i "%ENCODER%"=="hevc" set "TARGET_DIR=_Converted"
			if /i "!SRC_CODEC!"=="AVC"  if /i "%ENCODER%"=="h264" set "TARGET_DIR=_Converted"
			if /i "!SRC_CODEC!"=="AV1"  if /i "%ENCODER%"=="av1"  set "TARGET_DIR=_Converted"
		)
	)

	if defined TARGET_DIR (
		call :ENSURE_DIR "!TARGET_DIR!"
		set "MOVED_FILE=!TARGET_DIR!\!INBASE!.mkv"
		if /i "x!INNAME:~-4!"=="x.mkv" (
			echo %ESC%[91mWARNING: Source already encoded as !SRC_CODEC!. Moving to !TARGET_DIR!.%ESC%[0m
		) else (
			echo %ESC%[91mWARNING: Source already encoded as !SRC_CODEC!. Re-muxing to !TARGET_DIR!.%ESC%[0m
		)
		echo.

		REM Re-mux to normalize container. .mp4/.mov/.avi/.webm in .mkv umbenennen wuerde nicht
		REM funktionieren, weil der Inhalt kein echtes Matroska ist — EDIT_TAGS (mkvpropedit) wuerde
		REM scheitern und die Datei wandert in _Check. mkvmerge ist die richtige Loesung: schnell
		REM (Sekunden), kein Re-Encode, normales MKV-Container-Output.
		REM Sentinel 'x' prefix verhindert cmd.exe-Parse-Bug: 'if /i "x"=="y"' mit zwei
		REM benachbarten Quotes wird sonst als '"."' missinterpretiert.
		if /i "x!INNAME:~-4!"=="x.mkv" (
			move /Y "!INFILE!" "!MOVED_FILE!" >nul
		) else (
			mkvmerge -o "!MOVED_FILE!" "!INFILE!" >nul 2>&1
			if exist "!MOVED_FILE!" (
				if /i not "!INFILE!"=="!MOVED_FILE!" del /F "!INFILE!" >nul
			) else (
				echo %ESC%[91mWARNING: mkvmerge failed, falling back to plain move ^(file may be broken^).%ESC%[0m
				move /Y "!INFILE!" "!MOVED_FILE!" >nul
			)
		)

		for %%D in ("!MOVED_FILE!") do set "INDIR=%%~dpD"

		powershell -command "write-output ('file:///' + (get-item '!INDIR!').FullName.Replace('\', '/') -replace [char]34, [char]7 -replace ' ', '%%20' -replace '#', '%%23' -replace [char]39, '%%27' -replace [char]33, '%%21' -replace '\(', '%%28' -replace '\)', '%%29')"

		set "SKIP_FILE=1"
		if "%EDIT_TAGS%"=="1" call :EDIT_TAGS "!MOVED_FILE!"
		call :REMUX_IF_NEEDED "!MOVED_FILE!" "!MOVED_FILE!"
	)

	if not defined SKIP_FILE (
		%DBG% ==========================================
		%DBG% File: !INFILE!
		%DBG% CROP_MODE: "!CROP_MODE!"
		%DBG% ==========================================

		if "%ENCODER%"=="h264" (
			call :SETQUALITY-H264
		) else if "%ENCODER%"=="hevc" (
			call :SETQUALITY-HEVC
		) else if "%ENCODER%"=="av1" (
			call :SETQUALITY-HEVC
		)

		if "!AUTO_Q_FALLBACK!"=="1" (
			echo %ESC%[91mWARNING: No year found in filename. Falling back to default quality ^(!QUALITY!^).%ESC%[0m
		)

		if /i "!CROP_MODE!"=="AUTO" (
			set "PROBE_OK=0"
			%DBG% RUN_PROBE is being executed
			call :RUN_PROBE "!INFILE!"
			if "!PROBE_OK!"=="0" (
				%DBG% RUN_PROBE failed, moving file to _Check
				echo %ESC%[91mWARNING: Probe failed or source too small. Moving file to _Check.%ESC%[0m
				call :ENSURE_DIR "_Check"
				move /Y "!INFILE!" "_Check\" >nul
				set "SKIP_FILE=1"
			) else (
				if "!AUTO_CROP!"=="0:0:0:0" (
					%DBG% AUTO-CROP: no crop detected, passthrough
					set "CROP=--crop 0,0,0,0"
					set "RESIZE_REQUIRED=0"
					set "RESIZE_PARAM="
				) else (
					set "AUTO_CROP_FIX=!AUTO_CROP::=,!"
					set "CROP=--crop !AUTO_CROP_FIX! --output-res !AUTO_RES!"
					for /f "tokens=1,3 delims=:" %%A in ("!AUTO_CROP!") do (
						set "CROP_L=%%A"
						set "CROP_R=%%C"
					)
				)
				%DBG% AUTO-CROP final result: !CROP!
			)
		)

		if not "!CROP_MODE!"=="AUTO" if defined CROP (
			echo(!CROP! | findstr /i /c:"--output-res" >nul && (
				if not "!CROP!"=="--crop 0,0,0,0" (
					set "RESIZE_REQUIRED=1"
				)
			)
		)

		powershell -command "write-output ('file:///' + (get-item '!INDIR!').FullName.Replace('\', '/') -replace [char]34, [char]7 -replace ' ', '%%20' -replace '#', '%%23' -replace [char]39, '%%27' -replace [char]33, '%%21' -replace '\(', '%%28' -replace '\)', '%%29')"

		mediainfo --Inform="General;%%Duration/String2%% - %%FileSize/String4%%" "!INFILE!"

		%DBG% NVEnc parameters:
		%DBG%   CROP   = "!CROP!"
		%DBG%   FILTER = "!FILTER!"
		%DBG%   MODE   = "!MODE!"
		%DBG%   AUDIO  = "!AUDIO!"

		if not defined SKIP_FILE (
			set "RESIZE_PARAM="
			if "!RESIZE_REQUIRED!"=="1" if "!FILTER_HAS_RESIZE!"=="0" (
				set "RESIZE_PARAM=--vpp-resize spline36"
			)

			%DBG% RESIZE_REQUIRED   = "!RESIZE_REQUIRED!"
			%DBG% FILTER_HAS_RESIZE = "!FILTER_HAS_RESIZE!"
			%DBG% RESIZE_PARAM      = "!RESIZE_PARAM!"

			nvencc64.exe !NV_FLAGS! --thread-priority all=lowest --input-thread 1 --output-buf 16 !DECODER_PARAM! -i "!INFILE!" -c !ENCODER! --profile !PROFILE! --tier high --level auto --qvbr !QUALITY! !PRESET! --aq --aq-temporal --aq-strength 10 --lookahead 24 !TUNING! !B_REF! --bref-mode middle !RESIZE_PARAM! !CROP! !FILTER! !MODE! !AUDIO! --sub-copy --chapter-copy -o "_Converted\!INBASE!.mkv"
			if errorlevel 1 exit /b !ERRORLEVEL!

			if exist "_Converted\!INBASE!.mkv" (
				if "%EDIT_TAGS%"=="1" call :EDIT_TAGS "_Converted\!INBASE!.mkv"
				call :REMUX_IF_NEEDED "!INFILE!" "_Converted\!INBASE!.mkv"
			)

			for /L %%X in (5,-1,1) do (
				echo Waiting for %%X seconds...
				timeout /t 1 >nul
			)
			echo.
		)
	)
	endlocal
)
endlocal & set "FOUND=%FOUND%"
if "%FOUND%"=="0" (
	echo No files found.
) else (
	powershell -command "$o=ls . -inc *.mkv,*.mp4,*.avi,*.webm; $s=0; $d=0; foreach($f in $o){$c='_Converted\'+$f.Name; if(test-path $c){$s+=$f.Length; $d+=(ls $c).Length}}; if($s -gt 0){write-host ('[INFO] Savings: {0:N2} GB ({1:P1})' -f (($s-$d)/1GB), (($s-$d)/$s)) -fg Green}"
)
exit /b

:VALIDATE_ONE
if "%~1"=="" exit /b
set "VALID=0"
for %%A in (!%2!) do if /i "%~1"=="%%A" set "VALID=1"
if "!VALID!"=="0" (
	set "ERR_MSG=Invalid %3 '%~1' at position %4. Valid values: [!%2: =|!]"
	goto :PARAM_ERROR
)
exit /b

:VALIDATE-PARAMS
set "PARAM_ERR=0"

call :VALIDATE_ONE "%1" TOK_ENCODER encoder 1
call :VALIDATE_ONE "%2" TOK_AUDIO   audio   2
call :VALIDATE_ONE "%3" TOK_QUALITY quality 3
call :VALIDATE_ONE "%4" TOK_CROP    crop    4
call :VALIDATE_ONE "%5" TOK_FILTER  filter  5
call :VALIDATE_ONE "%6" TOK_MODE    mode    6
call :VALIDATE_ONE "%7" TOK_DECODER decoder 7
call :VALIDATE_ONE "%8" TOK_CHKENC  chkenc  8

exit /b

:PARAM_ERROR
set "PARAM_ERR=1"
echo %ESC%[91mERROR: !ERR_MSG!%ESC%[0m
exit /b

:EDIT_TAGS
if not exist "%~1" exit /b 1
setlocal EnableDelayedExpansion
set "S=" & set "E="
set "FILE=%~1"

%DBG% ==== EDIT_TAGS: enter !FILE!
for %%Z in ("!FILE!") do %DBG% EDIT_TAGS: file_size_before=%%~zZ

set "PS_SCRIPT=%TEMP%\edit_tags_%RANDOM%.ps1"
set "PS_SET_FILE=%TEMP%\edit_tags_set_%RANDOM%.cmd"

if exist "%PS_SCRIPT%" del /F "%PS_SCRIPT%"
if exist "%PS_SET_FILE%" del /F "%PS_SET_FILE%"

for /f "usebackq tokens=1 delims=:" %%A in (`findstr /n "^#PS_EDIT_TAGS_BEGIN#" "%~f0"`) do set /a S=%%A
for /f "usebackq tokens=1 delims=:" %%A in (`findstr /n "^#PS_EDIT_TAGS_END#"   "%~f0"`) do set /a E=%%A-S

%DBG% EDIT_TAGS: marker_S=!S! marker_E=!E!

if not defined S endlocal & exit /b 9
set /a E=E
if %E% LEQ 0 endlocal & exit /b 9

powershell -NoProfile -Command ^
  "$lines = Get-Content -Path '%~f0' -Encoding UTF8;" ^
  "$start = %S%;" ^
  "$end = $start + %E% - 1;" ^
  "$lines[$start..$end] | Out-File -FilePath '%PS_SCRIPT%' -Encoding utf8 -Force"

for %%Z in ("%PS_SCRIPT%") do %DBG% EDIT_TAGS: ps_script_size=%%~zZ

powershell.exe -NoProfile -ExecutionPolicy Bypass ^
  -File "%PS_SCRIPT%" "%FILE%" "%PS_SET_FILE%"

%DBG% EDIT_TAGS: ps_exit_code=!ERRORLEVEL!

if errorlevel 1 (
  echo EDIT_TAGS PowerShell failed
  call :ENSURE_DIR "_Check"
  move "%FILE%" "_Check\" >nul
  endlocal & exit /b 1
)

if not exist "%PS_SET_FILE%" (
  echo EDIT_TAGS: missing PS output
  call :ENSURE_DIR "_Check"
  move "%FILE%" "_Check\" >nul
  endlocal & exit /b 1
)

for %%Z in ("%PS_SET_FILE%") do %DBG% EDIT_TAGS: set_file_size=%%~zZ

call "%PS_SET_FILE%"

if defined EDIT_ACTIONS (
	for /f %%L in ('powershell -NoProfile -Command "Write-Output $env:EDIT_ACTIONS.Length" 2^>nul') do %DBG% EDIT_TAGS: edit_actions_length=%%L
	%DBG% EDIT_TAGS: edit_actions_head=!EDIT_ACTIONS:~0,200!
) else (
	%DBG% EDIT_TAGS: edit_actions_undefined
)

%DBG% EDIT_TAGS: running mkvpropedit...
if defined EDIT_ACTIONS (
  mkvpropedit "%FILE%" --edit info --delete title !EDIT_ACTIONS! >nul
) else (
  mkvpropedit "%FILE%" --edit info --delete title >nul
)
%DBG% EDIT_TAGS: mkvpropedit_exit_code=!ERRORLEVEL!

if errorlevel 1 (
	echo mkvpropedit failed
	call :ENSURE_DIR "_Check"
	move "%FILE%" "_Check\" >nul
	endlocal & exit /b 1
)

for %%Z in ("!FILE!") do %DBG% EDIT_TAGS: file_size_after=%%~zZ

for /f "usebackq delims=" %%V in (`mediainfo "--Inform=Video;%%Width%%x%%Height%%" "!FILE!" 2^>nul`) do %DBG% EDIT_TAGS: mediainfo_video=%%V
for /f "usebackq delims=" %%V in (`mediainfo "--Inform=General;%%VideoCount%%" "!FILE!" 2^>nul`) do %DBG% EDIT_TAGS: mediainfo_video_count=%%V
for /f "usebackq delims=" %%V in (`mediainfo "--Inform=General;%%AudioCount%%" "!FILE!" 2^>nul`) do %DBG% EDIT_TAGS: mediainfo_audio_count=%%V
for /f "usebackq delims=" %%V in (`mediainfo "--Inform=General;%%TextCount%%" "!FILE!" 2^>nul`) do %DBG% EDIT_TAGS: mediainfo_text_count=%%V
for /f "usebackq delims=" %%N in (`ffprobe -v error -show_entries format^=nb_streams -of default^=noprint_wrappers^=1:nokey^=1 "!FILE!" 2^>nul`) do %DBG% EDIT_TAGS: ffprobe_stream_count=%%N
for /f "usebackq tokens=1,2 delims=," %%W in (`ffprobe -v error -select_streams v:0 -show_entries stream^=width^,height -of csv^=p^=0 "!FILE!" 2^>nul`) do %DBG% EDIT_TAGS: ffprobe_video=%%Wx%%X

%DBG% ==== EDIT_TAGS: exit !FILE!

:EDIT_TAGS_CLEANUP
if exist "%PS_SCRIPT%" del /F "%PS_SCRIPT%"
if exist "%PS_SET_FILE%" del /F "%PS_SET_FILE%"
endlocal & exit /b

:REMUX_IF_NEEDED
if not exist "%~2" exit /b 0
setlocal EnableDelayedExpansion
set "FILE=%~2"
set "SOURCE=%~1"
set "CONVERTED=%~2"
set "NEEDS_REMUX=0"
set "FF_STREAMS="
set "MI_VIDEO_COUNT="

REM Ground truth via ffprobe (always reliable on intact files)
for /f "usebackq" %%N in (`ffprobe -v error -show_entries format^=nb_streams -of default^=noprint_wrappers^=1:nokey^=1 "!FILE!" 2^>nul`) do set "FF_STREAMS=%%N"

REM MediaInfo's view — empty if container has parse issues
for /f "usebackq" %%V in (`mediainfo "--Inform=General;%%VideoCount%%" "!FILE!" 2^>nul`) do set "MI_VIDEO_COUNT=%%V"

%DBG% REMUX_IF_NEEDED: file=!FILE! source=!SOURCE! ff_streams=!FF_STREAMS! mi_video=!MI_VIDEO_COUNT!

REM Branch 1: file is completely broken (ffprobe failed or saw 0 streams)
%DBG% REMUX_IF_NEEDED: branch_check FF_STREAMS=[!FF_STREAMS!] MI_VIDEO=[!MI_VIDEO_COUNT!]
if "!FF_STREAMS!"=="" goto :BRANCH_BROKEN
if "!FF_STREAMS!"=="0" goto :BRANCH_BROKEN
goto :BRANCH_HEALTHY

:BRANCH_BROKEN
call :ENSURE_DIR "_Check"
set "MOVE_OK=0"
if exist "!SOURCE!" (
	move /Y "!SOURCE!" "_Check\" >nul
	if not errorlevel 1 set "MOVE_OK=1"
) else (
	set "MOVE_OK=1"
)
if "!MOVE_OK!"=="1" (
	if /i not "!SOURCE!"=="!CONVERTED!" (
		if exist "!CONVERTED!" del /F "!CONVERTED!" >nul
		%DBG% REMUX_IF_NEEDED: broken file, source moved to _Check, _Converted cleaned
	) else (
		%DBG% REMUX_IF_NEEDED: broken file, source moved to _Check (same path as _Converted)
	)
) else (
	%DBG% REMUX_IF_NEEDED: broken file, move FAILED, _Converted preserved
)
endlocal & exit /b 0

:BRANCH_HEALTHY
REM Branch 2: re-mux if mediainfo can't parse but ffprobe can
if defined FF_STREAMS if not defined MI_VIDEO_COUNT set "NEEDS_REMUX=1"
if "!NEEDS_REMUX!"=="1" (
	set "REMUX_TMP=!FILE!.remux.tmp"
	mkvmerge -o "!REMUX_TMP!" "!FILE!" >nul 2>&1
	if exist "!REMUX_TMP!" (
		move /Y "!REMUX_TMP!" "!FILE!" >nul
		%DBG% REMUX_IF_NEEDED: re-muxed
	) else (
		%DBG% REMUX_IF_NEEDED: mkvmerge failed, file left as-is
	)
)
endlocal & exit /b 0

:RUN_PROBE
setlocal DisableDelayedExpansion
set "S=" & set "E="
set "PROBE_OK=0"
set "AUTO_CROP="
set "AUTO_RES="
set "NVEnc_Crop="
set "NVEnc_Res="
set "PS_SCRIPT=%TEMP%\probe_temp_%RANDOM%.ps1"
set "PS_SET_FILE=%TEMP%\probe_set_vars_%RANDOM%.cmd"
set "PS_STATUS_FILE=%TEMP%\probe_status_output_%RANDOM%.tmp"
if exist "%PS_SET_FILE%" del /F "%PS_SET_FILE%"
if exist "%PS_STATUS_FILE%" del /F "%PS_STATUS_FILE%"
for /f "usebackq tokens=1 delims=:" %%A in (`findstr /n "^#PS_RUN_PROBE_BEGIN#" "%~f0"`) do set /a S=%%A
for /f "usebackq tokens=1 delims=:" %%A in (`findstr /n "^#PS_RUN_PROBE_END#"   "%~f0"`) do set /a E=%%A-S

if not defined S endlocal & exit /b 9
set /a E=E
if %E% LEQ 0 endlocal & exit /b 9

powershell -NoProfile -Command ^
  "$lines = Get-Content -Path '%~f0' -Encoding UTF8;" ^
  "$start = %S%;" ^
  "$end = $start + %E% - 1;" ^
  "$lines[$start..$end] | Out-File -FilePath '%PS_SCRIPT%' -Encoding utf8 -Force"

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%PS_SCRIPT%" "%~1" -SetFile "%PS_SET_FILE%" -StatusFile "%PS_STATUS_FILE%"

set "RC=%ERRORLEVEL%"

if exist "%PS_SET_FILE%" call "%PS_SET_FILE%"

%DBG% RUN_PROBE: RC=%RC%
%DBG% RUN_PROBE: NVEnc_Crop=%NVEnc_Crop%
%DBG% RUN_PROBE: NVEnc_Res=%NVEnc_Res%

if exist "%PS_SCRIPT%" del /F "%PS_SCRIPT%"
if exist "%PS_SET_FILE%" del /F "%PS_SET_FILE%"
if exist "%PS_STATUS_FILE%" del /F "%PS_STATUS_FILE%"

if "%RC%"=="0" goto :PROBE_OK
if "%RC%"=="8" if defined NVEnc_Crop goto :PROBE_OK

endlocal & exit /b 1

:PROBE_OK
set "TEMP_CROP=%NVEnc_Crop%"
set "TEMP_RES=%NVEnc_Res%"
endlocal & (
	set "AUTO_CROP=%TEMP_CROP%"
	set "AUTO_RES=%TEMP_RES%"
	set "PROBE_OK=1"
)
exit /b 0

:PRINT_TOK
setlocal EnableDelayedExpansion

set "LABEL=%~1"
set "INFO=%~2"
set "TOKVAR=%~3"
set LABEL_PAD=10
set INFO_PAD=12
set PAD=22
set "SPACES=                              "

set "L=%LABEL%%SPACES%"
set "L=!L:~0,%LABEL_PAD%!"

set "I=%INFO%%SPACES%"
set "I=!I:~0,%INFO_PAD%!"

set "LEFT=!L!!I!"
set /a PAD1=%PAD%-1
set "INDENT=!SPACES:~0,%PAD1%!"

set "LINE=!LEFT!["
set FIRST=1
set WRAP=115

for %%T in (!%TOKVAR%!) do (
	if "!FIRST!"=="1" (
		set FIRST=0
		set "LINE=!LINE!%%T"
	) else (
		set "TEST=!LINE!|%%T"
		if not "!TEST:~0,%WRAP%!"=="!TEST!" (
			echo !LINE!]
			set "LINE=!INDENT! [%%T"
		) else (
			set "LINE=!LINE!|%%T"
		)
	)
)

echo !LINE!]
endlocal & exit /b

:USAGE
setlocal EnableDelayedExpansion
cls
set "USAGE_PARAMS=^<encoder^> [audio=ac3] [quality=28] [crop=none] [filter=none] [mode=none] [decoder=hw] [chkenc=true]"
set "EXAMPLE_PARAMS=hevc ac3 auto auto none none hw false"
set "EXAMPLE_PARAMS2=hevc ac3 auto none dehalo rtgmc"
if defined CALLER_NAME (
    set "COMMAND=%CALLER_NAME%"
) else (
    set "COMMAND=%~n0"
)
echo Usage: %COMMAND% %USAGE_PARAMS%
echo.
call :PRINT_TOK "encoder" "(required)"  TOK_ENCODER
call :PRINT_TOK "audio"   "(def=ac3)"   TOK_AUDIO
call :PRINT_TOK "quality" "(def=28)"    TOK_QUALITY
call :PRINT_TOK "crop"    "(def=none)"  TOK_CROP
call :PRINT_TOK "filter"  "(def=none)"  TOK_FILTER
call :PRINT_TOK "mode"    "(def=none)"  TOK_MODE
call :PRINT_TOK "decoder" "(def=hw)"    TOK_DECODER
call :PRINT_TOK "chkenc"  "(def=true)"  TOK_CHKENC
echo.
echo Example: %COMMAND% ^| %UL%encoder%NO% ^| %UL%audio%NO%   ^| %UL%quality%NO% ^| %UL%crop%NO%    ^| %UL%filter%NO%  ^| %UL%mode%NO%    ^| %UL%decoder%NO% ^| %UL%chkenc%NO%  ^|
echo Example: %COMMAND% ^| hevc    ^| ac3     ^|         ^|         ^|         ^|         ^|         ^|         ^|
echo Example: %COMMAND% ^| hevc    ^| ac3     ^| auto    ^| auto    ^|         ^|         ^|         ^|         ^|
echo Example: %COMMAND% ^| hevc    ^| copy    ^| auto    ^| 1080    ^| vsr     ^|         ^|         ^|         ^|
echo Example: %COMMAND% ^| hevc    ^| copy    ^| hq      ^| 1080    ^| gauss   ^|         ^| sw      ^| true    ^|
echo Example: %COMMAND% ^| hevc    ^| ac3     ^| auto    ^| auto    ^| none    ^| none    ^| hw      ^| false   ^|
echo.
echo Example: %COMMAND% %EXAMPLE_PARAMS%
echo Example: %COMMAND% %EXAMPLE_PARAMS2%
echo.
endlocal
goto :END

:SETESC
for /f "usebackq delims=" %%A in (`echo prompt $E^| cmd`) do set "ESC=%%A"
set "UL=%ESC%[4m"
set "NO=%ESC%[24m"
exit /b

:SETTOKEN
set "TOK_ENCODER=def hevc he10 h264 av1"
set "TOK_AUDIO=copy copy1 copy2 copy12 copy23 ac3 aac eac3"
set "TOK_QUALITY=def auto hq uhq lq ulq"
set "TOK_CROP=none auto 43 169 696 752 768 800 804 808 812 816 872 960 1012 1024 1036 1040 720 720p 720f 1080 1080p 1080f 2160 2160p 2160f 1440 1348 1408 1420 1480 1500 1620 1764 1780 1788 1792 1800 c1 c2 c3 c4 c5 c6"
set "TOK_FILTER=none edgelevel smooth smoothlq smoothhq nlmeans gauss gauss5 sharp denoise denoisehq artifact artifacthq superres superreshq vsr vsrdenoise vsrdenoisehq vsrartifact vsrartifacthq dehalo dehalo2 log f1 f2 f3 f4 f5 f6"
set "TOK_MODE=none deint ivtc rtgmc rtgmcp double 23fps 25fps 30fps 60fps 29fps 59fps lighter darker vintage linear tweak HDRtoSDR HDRtoSDRR HDRtoSDRM HDRtoSDRH dv dolby-vision"
set "TOK_DECODER=def hw sw auto"
set "TOK_CHKENC=def true false"
exit /b

:NOP
exit /b

:ENSURE_DIR
if not exist "%~1" md "%~1"
exit /b

:DEBUG
setlocal EnableDelayedExpansion
set "DBG_MSG=%*"
echo [DEBUG] !DBG_MSG!
endlocal & exit /b

:END
exit /b 0

#PS_RUN_PROBE_BEGIN#
param(
	[Parameter(Position=0, Mandatory=$true)]
	[string]$VideoFile,
	[Parameter(Mandatory=$true)]
	[string]$SetFile,
	[Parameter(Mandatory=$true)]
	[string]$StatusFile
)
$ExitCode = 0
$RejectReason = $null
function Write-Status ($Message) {
	$Timestamp = Get-Date -Format "HH:mm:ss"
	Add-Content -Path $StatusFile -Value "[$Timestamp] $Message"
}
function Get-Median {
	param([int[]]$Numbers)
	$Count = $Numbers.Count
	if ($Count -eq 0) { return 0 }
	$Sorted = $Numbers | Sort-Object
	if ($Count % 2 -eq 1) {
		return $Sorted[[math]::Floor($Count / 2)]
	} else {
		return [int](($Sorted[($Count / 2) - 1] + $Sorted[$Count / 2]) / 2)
	}
}
$StandardResolutions = @{
	384 = @{ Crop="0:192:0:192"; Res="1920x696" }
    328 = @{ Crop="0:164:0:164"; Res="1920x752" }
    312 = @{ Crop="0:156:0:156"; Res="1920x768" }
	280 = @{ Crop="0:140:0:140"; Res="1920x800" }
	276 = @{ Crop="0:138:0:138"; Res="1920x804" }
	272 = @{ Crop="0:136:0:136"; Res="1920x808" }
	268 = @{ Crop="0:134:0:134"; Res="1920x812" }
	264 = @{ Crop="0:132:0:132"; Res="1920x816" }
	208 = @{ Crop="0:104:0:104"; Res="1920x872" }
	120 = @{ Crop="0:60:0:60";	 Res="1920x960" }
	 68 = @{ Crop="0:34:0:34";	 Res="1920x1012" }
	 56 = @{ Crop="0:28:0:28";	 Res="1920x1024" }
	 44 = @{ Crop="0:22:0:22";	 Res="1920x1036" }
	 40 = @{ Crop="0:20:0:20";	 Res="1920x1040" }
	  0 = @{ Crop="0:0:0:0";	 Res="1920x1080" }
}
$StandardWidths = @(1800,1792,1788,1780,1764,1500,1620,1480,1440,1420,1408,1348)
$ffmpegCmd = (get-command ffmpeg.exe).source
$ffprobeCmd = (get-command ffprobe.exe).source
$ProbeTimes = @("00:02:00","00:10:00","00:20:00")
$CropResults = @()
if (-not (Test-Path $VideoFile)) { $ExitCode = 1 }
if ($ExitCode -eq 0) {
	$ResolutionInfo = & $ffprobeCmd -v error -select_streams v:0 -show_entries stream=width,height -of default=noprint_wrappers=1:nokey=1 $VideoFile 2>&1
	$CleanRes = $ResolutionInfo | Where-Object { $_ -match '^\d+$' }
	if ($CleanRes.Count -lt 2) { $ExitCode = 2 }
	$OrigWidth	= [int]$CleanRes[0]
	$OrigHeight = [int]$CleanRes[1]
	if ($OrigWidth -lt 1280 -or $OrigHeight -lt 696) {
		$RejectReason = "source too small (${OrigWidth}x${OrigHeight})"
	}
	if ($RejectReason) {
		Write-Status "REJECTED: $RejectReason"
		exit 8
	}
}
if ($ExitCode -eq 0) {
	foreach ($Time in $ProbeTimes) {
		$out = & $ffmpegCmd -ss $Time -i $VideoFile -t 5 -vf "cropdetect=limit=24:round=2:reset=0" -f null - 2>&1
		$m = [regex]::Matches($out,"crop=(\d+:\d+:\d+:\d+)") | Select-Object -Last 1
		if ($m) {
			$c = ($m.Value -replace 'crop=','') -split ':'
			$CropResults += [PSCustomObject]@{ W=[int]$c[0]; H=[int]$c[1]; X=[int]$c[2]; Y=[int]$c[3] }
		}
	}
	if ($CropResults.Count -eq 0) { $ExitCode = 4 }
}
if ($ExitCode -eq 0) {
	$W = Get-Median $CropResults.W
	$H = Get-Median $CropResults.H
	$X = Get-Median $CropResults.X
	$Y = Get-Median $CropResults.Y
	$CropL = $X; $CropR=$OrigWidth-$X-$W
	$CropT = $Y; $CropB=$OrigHeight-$Y-$H
	$TotalV = $CropT + $CropB
	$TotalH = $CropL + $CropR
	if ($TotalV -le 4 -and $TotalH -le 10) {
		"SET NVEnc_Crop=0:0:0:0" | Out-File -Encoding ASCII $SetFile
		"SET NVEnc_Res=${OrigWidth}x${OrigHeight}" | Out-File -Encoding ASCII $SetFile -Append
		exit 0
	}
	if ($TotalV -le 2 -and $TotalH -gt 8) {
		$BestW = $StandardWidths |
			Sort-Object { [math]::Abs($_ - ($OrigWidth - $TotalH)) } |
			Select-Object -First 1
		$Side = [int](($OrigWidth - $BestW) / 2)
		"SET NVEnc_Crop=${Side}:0:${Side}:0" | Out-File -Encoding ASCII $SetFile
		"SET NVEnc_Res=${BestW}x${OrigHeight}" | Out-File -Encoding ASCII $SetFile -Append
		exit 0
	}
	if ([math]::Abs($CropT - $CropB) -gt 10) {
		$RejectReason = "vertical asymmetry (T=$CropT B=$CropB)"
	}
	elseif ( ($CropT -eq 0 -and $CropB -gt 0) -or ($CropB -eq 0 -and $CropT -gt 0) ) {
		$RejectReason = "one-sided vertical crop (T=$CropT B=$CropB)"
	}
	elseif ($TotalV -eq 0 -and [math]::Abs($CropL - $CropR) -gt 2) {
		$RejectReason = "horizontal asymmetry (no matching standard width)"
	}
	if ($RejectReason) {
		Write-Status "REJECTED: $RejectReason"
		exit 8
	}
	$Best = $StandardResolutions.GetEnumerator() | Sort-Object { [math]::Abs($_.Key-$TotalV) } | Select-Object -First 1
	$Top=$Best.Value.Crop.Split(':')[1]
	$Bottom=$Best.Value.Crop.Split(':')[3]
	$TargetH=$Best.Value.Res.Split('x')[1]
	$FinalL=0; $TargetW=$OrigWidth
	$NVEncCrop="${FinalL}:${Top}:${FinalL}:${Bottom}"
	$NVEncRes="${TargetW}x$TargetH"
	"SET NVEnc_Crop=$NVEncCrop" | Out-File -Encoding ASCII $SetFile
	"SET NVEnc_Res=$NVEncRes"	| Out-File -Encoding ASCII $SetFile -Append
}
exit $ExitCode
#PS_RUN_PROBE_END#

#PS_EDIT_TAGS_BEGIN#
param(
	[string]$VideoFile,
	[string]$SetFile
)
$ErrorActionPreference='Stop'
$j=& mkvmerge.exe -J "$VideoFile" | ConvertFrom-Json
$actions=@()
function IsPureLang($n){
	if([string]::IsNullOrWhiteSpace($n)){return $false}
	$n -match '^(?i)(Deutsch|Englisch|German|English|French|Stereo|Surround)$'
}
function IsFullWord($n){
	$n -match '^(?i)full$'
}
function NormalizeName($n){
	if([string]::IsNullOrWhiteSpace($n)){return $null}
	if($n -match '(?i)sdh'){ return 'SDH' }
	if($n -match '(?i)forced'){ return 'Forced' }
	return $null
}
$audioGer=@()
foreach($t in $j.tracks){
	if($t.type -eq 'audio' -and $t.properties.language -match '^(?i)(ger|deu)$'){
		$audioGer+=$t
	}
}
$defaultAudioNum=$null
if($audioGer.Count -gt 0){
	$defaultAudioNum=$audioGer[0].properties.number
}
$forcedDone = $false
foreach($t in $j.tracks){
	$num=$t.properties.number
	$type=$t.type
	$name=$t.properties.track_name
	if($type -eq 'video'){
		$actions+="--edit track:$num --set language=und --set flag-default=0 --set flag-forced=0 --delete name"
		continue
	}
	if($type -eq 'audio'){
		$actions+="--edit track:$num --set flag-forced=0"
		if($num -eq $defaultAudioNum){
			$actions+="--edit track:$num --set flag-default=1"
		}else{
			$actions+="--edit track:$num --set flag-default=0"
		}
		if(-not [string]::IsNullOrWhiteSpace($name)){
			$normalizedName = NormalizeName $name
			if($null -ne $normalizedName){
				$actions+="--edit track:$num --set name=$normalizedName"
			}elseif(IsPureLang $name){
				$actions+="--edit track:$num --delete name"
			}elseif(IsFullWord $name){
				$actions+="--edit track:$num --delete name"
			}
		}
		continue
	}
	if($type -eq 'subtitles'){
		$isForced = $false
		if($t.properties.forced_track -eq $true){ $isForced = $true }
		if($name -match '(?i)forced'){ $isForced = $true }
	
		if($isForced){
			if(-not $forcedDone){
				$actions+="--edit track:$num --set flag-default=1 --set flag-forced=1"
				$forcedDone = $true
			} else {
				$actions+="--edit track:$num --set flag-default=0 --set flag-forced=1"
			}
		} else {
			$actions+="--edit track:$num --set flag-default=0 --set flag-forced=0"
		}
		if(-not [string]::IsNullOrWhiteSpace($name)){
			$normalizedName = NormalizeName $name
			if($null -ne $normalizedName){
				$actions+="--edit track:$num --set name=$normalizedName"
			}elseif(IsPureLang $name){
				$actions+="--edit track:$num --delete name"
			}elseif(IsFullWord $name){
				$actions+="--edit track:$num --delete name"
			}
		}
		continue
	}
}
[System.IO.File]::WriteAllText($SetFile, "SET EDIT_ACTIONS=$($actions -join ' ')", [System.Text.Encoding]::ASCII)
#PS_EDIT_TAGS_END#
