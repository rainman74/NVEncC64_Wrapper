@echo off & setlocal enabledelayedexpansion

:INIT
call :SETESC
call :SETTOKEN
set "FF_FLAGS=-v info -hide_banner -stats -err_detect ignore_err -fflags +genpts+igndts"

if '%1'=='-h' goto USAGE
if '%1'=='' goto USAGE

set "EDIT_TAGS=1"
set "DEBUG=0"
if "%DEBUG%"=="1" (set "DBG=call :DEBUG") else (set "DBG=call :NOP")

call :VALIDATE-PARAMS %*
if "!PARAM_ERR!"=="1" goto :END

call :SETENCODER %1 %2 %3 %4 %5 %6 %7 %8
call :SETAUDIO   %1 %2 %3 %4 %5 %6 %7 %8
call :SETCROP    %1 %2 %3 %4 %5 %6 %7 %8
call :SETFILTER  %1 %2 %3 %4 %5 %6 %7 %8
call :SETMODE    %1 %2 %3 %4 %5 %6 %7 %8
call :SETDECODER %1 %2 %3 %4 %5 %6 %7 %8
call :SETCHKENC  %1 %2 %3 %4 %5 %6 %7 %8

set "DECODER_PARAM="
if defined DECODER set "DECODER_PARAM=!DECODER!"

set "REQ_Q=%3"
set "CROP_PARAM=%4"
if "!REQ_Q!"=="" set "REQ_Q=def"

set "FILTER_HAS_RESIZE=0"
set "FILTER_HAS_SCALE_CUDA=0"
set "FILTER_HAS_HWUPLOAD=0"

if defined FILTER (
	echo(!FILTER! | findstr /i /c:"scale_cuda" >nul && (
		set "FILTER_HAS_RESIZE=1"
		set "FILTER_HAS_SCALE_CUDA=1"
	)
	if "!FILTER_HAS_RESIZE!"=="0" (
		echo(!FILTER! | findstr /i /c:"scale" >nul && set "FILTER_HAS_RESIZE=1"
	)
	echo(!FILTER! | findstr /i /c:"hwupload_cuda" >nul && set "FILTER_HAS_HWUPLOAD=1"
)

if defined MODE (
	echo(!MODE! | findstr /i /c:"scale_cuda" >nul && (
		set "FILTER_HAS_RESIZE=1"
		set "FILTER_HAS_SCALE_CUDA=1"
	)
	if "!FILTER_HAS_RESIZE!"=="0" (
		echo(!MODE! | findstr /i /c:"scale" >nul && set "FILTER_HAS_RESIZE=1"
	)
	echo(!MODE! | findstr /i /c:"hwupload_cuda" >nul && set "FILTER_HAS_HWUPLOAD=1"
)

call :MAIN
goto :END

:SETQUALITY-HEVC
set "AUTO_Q_FALLBACK=0"
set "ACTUAL_Q=!REQ_Q!"
if "!REQ_Q!"=="auto" (
	set "ACTUAL_Q=none"
	echo "!FILENAME!" | findstr /c:"(19" >nul && set "ACTUAL_Q=hq"
	echo "!FILENAME!" | findstr /c:"(20" >nul && set "ACTUAL_Q=def"
	if "!ACTUAL_Q!"=="none" (set "ACTUAL_Q=def" & set "AUTO_Q_FALLBACK=1")
)
set "PRESET=-preset:v p7"
set "TUNING=-tune:v hq"
set "B_REF=-bf:v 3 -refs:v 4 -b_ref_mode:v middle"
if "!ACTUAL_Q!"=="uhq"		(set "QUALITY=22" & set "TUNING=-tune:v hq" & set "B_REF=-bf:v 4 -refs:v 4 -b_ref_mode:v middle")
if "!ACTUAL_Q!"=="hq"		(set "QUALITY=24")
if "!ACTUAL_Q!"=="def"		(set "QUALITY=26")
if "!ACTUAL_Q!"=="lq"		(set "QUALITY=28")
if "!ACTUAL_Q!"=="ulq"		(set "QUALITY=30" & set "TUNING=-tune:v ll" & set "PRESET=-preset p1" & set "B_REF=-bf:v 3 -refs:v 4 -b_ref_mode:v disabled")
exit /b

:SETQUALITY-H264
set "AUTO_Q_FALLBACK=0"
set "ACTUAL_Q=!REQ_Q!"
if "!REQ_Q!"=="auto" (
	set "ACTUAL_Q=none"
	echo "!FILENAME!" | findstr /c:"(19" >nul && set "ACTUAL_Q=hq"
	echo "!FILENAME!" | findstr /c:"(20" >nul && set "ACTUAL_Q=def"
	if "!ACTUAL_Q!"=="none" (set "ACTUAL_Q=def" & set "AUTO_Q_FALLBACK=1")
)
set "PRESET=-preset:v p7"
set "TUNING=-tune:v hq"
set "B_REF=-bf:v 3 -refs:v 4"
if "!ACTUAL_Q!"=="uhq"		(set "QUALITY=20" & set "TUNING=-tune:v hq" & set "B_REF=-bf:v 4 -refs:v 4")
if "!ACTUAL_Q!"=="hq"		(set "QUALITY=22")
if "!ACTUAL_Q!"=="def"		(set "QUALITY=24")
if "!ACTUAL_Q!"=="lq"		(set "QUALITY=26")
if "!ACTUAL_Q!"=="ulq"		(set "QUALITY=28" & set "TUNING=-tune:v ll" & set "PRESET=-preset p1" & set "B_REF=-bf:v 3 -refs:v 4")
exit /b

:SETENCODER
set "ENCODER=hevc_nvenc" & set "PROFILE=main"
if "%1"=="def"				(set "ENCODER=hevc_nvenc" & set "PROFILE=main")
if "%1"=="hevc"				(set "ENCODER=hevc_nvenc" & set "PROFILE=main")
if "%1"=="he10"				(set "ENCODER=hevc_nvenc" & set "PROFILE=main10")
if "%1"=="h264"				(set "ENCODER=h264_nvenc" & set "PROFILE=high")
if "%1"=="av1"				(set "ENCODER=av1_nvenc"  & set "PROFILE=main")
if "%1"=="av10"				(set "ENCODER=av1_nvenc"  & set "PROFILE=main")
exit /b

:SETAUDIO
set "AUDIO=AUTO_LOGIC"
if "%2"=="copy"				(set "AUDIO=-c:a copy")
if "%2"=="copy1"			(set "AUDIO=-map 0:a:0 -c:a copy")
if "%2"=="copy2"			(set "AUDIO=-map 0:a:1 -c:a copy")
if "%2"=="copy12"			(set "AUDIO=-map 0:a:0 -c:a:0 copy -map 0:a:1 -c:a:1 copy")
if "%2"=="copy23"			(set "AUDIO=-map 0:a:1 -c:a:0 copy -map 0:a:2 -c:a:1 copy")
if "%2"=="ac3"				(set "AUDIO=AUTO_LOGIC")
if "%2"=="aac"				(set "AUDIO=AUTO_LOGIC")
if "%2"=="eac3"				(set "AUDIO=AUTO_LOGIC")
exit /b

:SETCROP
set "CROP_VAL=" & set "CROP_MODE="
if /i "%4"=="auto" (
	set "CROP_MODE=AUTO"
	exit /b
)
if /i "%4"=="none" (
	set "CROP_VAL="
	exit /b
)
if "%4"=="696"				(set "CROP_VAL=crop=1920:696:0:192")
if "%4"=="768"				(set "CROP_VAL=crop=1920:768:0:156")
if "%4"=="800"				(set "CROP_VAL=crop=1920:800:0:140")
if "%4"=="804"				(set "CROP_VAL=crop=1920:804:0:138")
if "%4"=="808"				(set "CROP_VAL=crop=1920:808:0:136")
if "%4"=="812"				(set "CROP_VAL=crop=1920:812:0:134")
if "%4"=="816"				(set "CROP_VAL=crop=1920:816:0:132")
if "%4"=="872"				(set "CROP_VAL=crop=1920:872:0:104")
if "%4"=="960"				(set "CROP_VAL=crop=1920:960:0:60")
if "%4"=="1012"				(set "CROP_VAL=crop=1920:1012:0:34")
if "%4"=="1024"				(set "CROP_VAL=crop=1920:1024:0:28")
if "%4"=="1036"				(set "CROP_VAL=crop=1920:1036:0:22")
if "%4"=="1040"				(set "CROP_VAL=crop=1920:1040:0:20")
if "%4"=="720"				(set "CROP_VAL=scale=1280:-1")
if "%4"=="720p"				(set "CROP_VAL=scale=-2:720")
if "%4"=="720f"				(set "CROP_VAL=scale=1280:720")
if "%4"=="1080"				(set "CROP_VAL=scale=1920:-1")
if "%4"=="1080p"			(set "CROP_VAL=scale=-2:1080")
if "%4"=="1080f"			(set "CROP_VAL=scale=1920:1080")
if "%4"=="2160"				(set "CROP_VAL=scale=3840:-1")
if "%4"=="2160p"			(set "CROP_VAL=scale=-2:2160")
if "%4"=="2160f"			(set "CROP_VAL=scale=3840:2160")
if "%4"=="1440"				(set "CROP_VAL=crop=1440:1080:240:0")
if "%4"=="1440f"			(set "CROP_VAL=crop=1440:1080:0:0")
if "%4"=="1348"				(set "CROP_VAL=crop=1348:1080:286:0")
if "%4"=="1420"				(set "CROP_VAL=crop=1420:1080:250:0")
if "%4"=="1480"				(set "CROP_VAL=crop=1480:1080:220:0")
if "%4"=="1500"				(set "CROP_VAL=crop=1500:1080:210:0")
if "%4"=="1764"				(set "CROP_VAL=crop=1764:1080:78:0")
if "%4"=="1780"				(set "CROP_VAL=crop=1780:1080:70:0")
if "%4"=="1788"				(set "CROP_VAL=crop=1788:1080:66:0")
if "%4"=="1792"				(set "CROP_VAL=crop=1792:1080:64:0")
if "%4"=="1800"				(set "CROP_VAL=crop=1800:1080:60:0")
if "%4"=="c1"				(set "CROP_VAL=crop=1920:804:0:2")
if "%4"=="c2"				(set "CROP_VAL=")
if "%4"=="c3"				(set "CROP_VAL=")
if "%4"=="c4"				(set "CROP_VAL=")
if "%4"=="c5"				(set "CROP_VAL=")
if "%4"=="c6"				(set "CROP_VAL=")
exit /b

:SETFILTER
set "FILTER="
if "%5"=="none"				(set "FILTER=")
if "%5"=="text"				(set "FILTER=drawtext=text='Hallo Welt':font='Arial':fontsize=24:fontcolor=white:x=100:y=100")
if "%5"=="reverb"			(set "FILTER=afftdn=nr=97:nt=0")
if "%5"=="deblock"			(set "FILTER=hqdn3d=3:3:6:6")
if "%5"=="edgelevel"		(set "FILTER=unsharp=5:5:0.5")
if "%5"=="smooth"			(set "FILTER=avgblur=sizeX=3:sizeY=3")
if "%5"=="smooth31"			(set "FILTER=avgblur=sizeX=31:sizeY=31")
if "%5"=="smooth63"			(set "FILTER=avgblur=sizeX=63:sizeY=63")
if "%5"=="nlmeans"			(set "FILTER=nlmeans=s=1.5:p=7:r=15")
if "%5"=="gauss"			(set "FILTER=gblur=sigma=1")
if "%5"=="gauss5"			(set "FILTER=gblur=sigma=5")
if "%5"=="sharp"			(set "FILTER=unsharp=5:5:1.0")
if "%5"=="denoise"			(set "FILTER=atadenoise=0.05:0.05:0.3")
if "%5"=="denoisehq"		(set "FILTER=dctdnoiz=s=4.5,atadenoise=0.05:0.05:0.3")
if "%5"=="artifact"			(set "FILTER=deblock=filter=weak")
if "%5"=="artifacthq"		(set "FILTER=deblock=filter=strong")
if "%5"=="superres"			(set "FILTER=scale=2*iw:2*ih:flags=lanczos")
if "%5"=="superreshq"		(set "FILTER=scale=2*iw:2*ih:flags=spline")
if "%5"=="log"				(set "FILTER=")
if "%5"=="ushrp"			(set "FILTER=scale=2*iw:2*ih:flags=lanczos,unsharp=5:5:1.0")
if "%5"=="ushrpdenoise"		(set "FILTER=scale=2*iw:2*ih:flags=lanczos,unsharp=5:5:1.0,atadenoise=0.05:0.05:0.3")
if "%5"=="ushrpdenoisehq"	(set "FILTER=scale=2*iw:2*ih:flags=lanczos,unsharp=5:5:1.0,dctdnoiz=s=4.5,atadenoise=0.05:0.05:0.3")
if "%5"=="ushrpartifact"	(set "FILTER=scale=2*iw:2*ih:flags=lanczos,unsharp=5:5:1.0,deblock=filter=weak")
if "%5"=="ushrpartifacthq"	(set "FILTER=scale=2*iw:2*ih:flags=lanczos,unsharp=5:5:1.0,deblock=filter=strong")
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
if "%6"=="deint"			(set "MODE=bwdif=mode=send_frame:parity=auto:deint=all")
if "%6"=="yadif"			(set "MODE=yadif=0:-1:0")
if "%6"=="yadifbob"			(set "MODE=yadif=1:-1:0")
if "%6"=="double"			(set "MODE=minterpolate=fps=60")
if "%6"=="23fps"			(set "MODE=fps=23.976")
if "%6"=="25fps"			(set "MODE=fps=25")
if "%6"=="30fps"			(set "MODE=fps=30")
if "%6"=="60fps"			(set "MODE=fps=60")
if "%6"=="29fps"			(set "MODE=fps=29.97")
if "%6"=="59fps"			(set "MODE=fps=59.94")
if "%6"=="tweak"			(set "MODE=eq=brightness=0.0:contrast=1.0:gamma=1.0:saturation=1.0:hue=0.0")
if "%6"=="brighter"			(set "MODE=eq=brightness=0.03")
if "%6"=="darker"			(set "MODE=eq=brightness=-0.03")
if "%6"=="lighter"			(set "MODE=eq=brightness=0.03")
if "%6"=="vintage"			(set "MODE=curves=vintage")
if "%6"=="linear"			(set "MODE=curves=g=0/0.5/1:r=0/0.5/1:b=0/0.5/1")
if "%6"=="HDRtoSDR"			(set "MODE=zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=bt2390:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p")
if "%6"=="HDRtoSDRR"		(set "MODE=zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=reinhard:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p")
if "%6"=="HDRtoSDRM"		(set "MODE=zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=mobius:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p")
if "%6"=="HDRtoSDRH"		(set "MODE=zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p")
if "%6"=="dv"				(set "MODE=libplacebo=tonemapping=bt2390")
if "%6"=="dolby-vision"		(set "MODE=libplacebo=tonemapping=bt2390")
exit /b

:SETDECODER
set "DECODER=-hwaccel auto"
if "%7"=="def"				(set "DECODER=-hwaccel auto")
if "%7"=="cuda"				(set "DECODER=-hwaccel cuda -hwaccel_output_format cuda")
if "%7"=="cuvid"			(set "DECODER=-hwaccel cuvid")
if "%7"=="vp8"				(set "DECODER=-hwaccel cuvid -c:v vp8_cuvid")
if "%7"=="vp9"				(set "DECODER=-hwaccel cuvid -c:v vp9_cuvid")
if "%7"=="vpx"				(set "DECODER=-hwaccel cuvid -c:v libvpx")
if "%7"=="sw"				(set "DECODER=")
if "%7"=="mpeg2"			(set "DECODER=-hwaccel cuvid -c:v mpeg2_cuvid -deint adaptive")
if "%7"=="auto"				(set "DECODER=-hwaccel auto")
exit /b

:SETCHKENC
set "CHECK_ENCODED=1"
if "%8"=="def"     (set "CHECK_ENCODED=1")
if "%8"=="true"    (set "CHECK_ENCODED=1")
if "%8"=="false"   (set "CHECK_ENCODED=0")
exit /b

:MAIN
call :ENSURE_DIR "_Converted"
set "FOUND=0"
for %%I in (*.mkv *.mp4 *.mpg *.mov *.avi *.webm) do if exist "%%I" if not exist "_Converted\%%~nI.mkv" (
	echo %ESC%[101;93m %%I %ESC%[0m

	set "FOUND=1"
	set "FILENAME=%%~nI"
	set "SKIP_FILE="
	set "TARGET_DIR="
	set "RESIZE_REQUIRED=0"
	set "AUTO_RES_W="
	set "AUTO_RES_W="
	set "AUTO_RES_H="
	set "SRC_CODEC="

	for /f "usebackq delims=" %%C in (`cmd /c mediainfo "--Inform=Video;%%Format%%" "%%I" 2^>nul`) do (
		set "SRC_CODEC=%%C"
	)

	if not defined SRC_CODEC (
		echo ERROR: Could not detect codec. Moving file to _Check.
		call :ENSURE_DIR "_Check"
		move /Y "%%I" "_Check\" >nul
		set "SKIP_FILE=1"
	) else (
		if "%CHECK_ENCODED%"=="1" (
			if /i "!SRC_CODEC!"=="HEVC" if /i "%ENCODER%"=="hevc_nvenc" set "TARGET_DIR=_Converted"
			if /i "!SRC_CODEC!"=="AVC"  if /i "%ENCODER%"=="h264_nvenc" set "TARGET_DIR=_Converted"
			if /i "!SRC_CODEC!"=="AV1"  if /i "%ENCODER%"=="av1_nvenc"  set "TARGET_DIR=_Converted"
		)
	)

	if defined TARGET_DIR (
		call :ENSURE_DIR "!TARGET_DIR!"
		set "MOVED_FILE=!TARGET_DIR!\%%~nI.mkv"
		if /i "x%%~xI"=="x.mkv" (
			echo %ESC%[91mWARNING: Source already encoded as !SRC_CODEC!. Moving to !TARGET_DIR!.%ESC%[0m
		) else (
			echo %ESC%[91mWARNING: Source already encoded as !SRC_CODEC!. Re-muxing to !TARGET_DIR!.%ESC%[0m
		)
		echo.

		if /i "x%%~xI"=="x.mkv" (
			move /Y "%%I" "!MOVED_FILE!" >nul
		) else (
			mkvmerge -o "!MOVED_FILE!" "%%I" >nul 2>&1
			if exist "!MOVED_FILE!" (
				if /i not "%%I"=="!MOVED_FILE!" del /F "%%I" >nul
			) else (
				echo %ESC%[91mWARNING: mkvmerge failed, falling back to plain move ^(file may be broken^).%ESC%[0m
				move /Y "%%I" "!MOVED_FILE!" >nul
			)
		)

		setlocal DisableDelayedExpansion
		powershell -command "write-output ('file:///' + (get-item '%%~dpI').FullName.Replace('\', '/') -replace [char]34, [char]7 -replace ' ', '%%20' -replace '#', '%%23' -replace [char]39, '%%27' -replace '!', '%%21' -replace '\(', '%%28' -replace '\)', '%%29')"
		endlocal

		set "SKIP_FILE=1"
		if "%EDIT_TAGS%"=="1" call :EDIT_TAGS "!MOVED_FILE!"
		call :REMUX_IF_NEEDED "%%I" "!MOVED_FILE!"
	)

	if not defined SKIP_FILE (
		%DBG% ==========================================
		%DBG% File: %%I
		%DBG% CROP_MODE: "!CROP_MODE!"
		%DBG% ==========================================

		call :SETCROP x x x !CROP_PARAM!

		if "!AUDIO!"=="AUTO_LOGIC" (
			call :APPLY_DYNAMIC_AUDIO "%%I" "%2"
		) else (
			set "AUDIO_ARGS=!AUDIO!"
		)

		if "%ENCODER%"=="h264_nvenc" (
			call :SETQUALITY-H264
		) else if "%ENCODER%"=="hevc_nvenc" (
			call :SETQUALITY-HEVC
		) else if "%ENCODER%"=="av1_nvenc" (
			call :SETQUALITY-HEVC
		)

		if "!AUTO_Q_FALLBACK!"=="1" (
			echo %ESC%[91mWARNING: No year found in filename. Falling back to default quality (!QUALITY!^).%ESC%[0m
		)

		if /i "!CROP_MODE!"=="AUTO" set "CROP_VAL="

		if /i "!CROP_MODE!"=="AUTO" (
			set "PROBE_OK=0"
			%DBG% RUN_PROBE is being executed
			call :RUN_PROBE "%%I"

			if "!PROBE_OK!"=="0" (
				%DBG% RUN_PROBE failed, moving file to _Check
				echo %ESC%[91mWARNING: Probe failed or source too small. Moving file to _Check.%ESC%[0m
				call :ENSURE_DIR "_Check"
				move /Y "%%I" "_Check\" >nul
				set "SKIP_FILE=1"
			) else (
				if "!AUTO_CROP!"=="0:0:0:0" (
					%DBG% AUTO-CROP: no crop detected, passthrough
					set "CROP_VAL=null"
					set "RESIZE_REQUIRED=0"
				) else (
					for /f "tokens=1,2,3,4 delims=:" %%a in ("!AUTO_CROP!") do (
						set /a "crop_w=1920 - %%a - %%c"
						set /a "crop_h=1080 - %%b - %%d"
						set "CROP_VAL=crop=!crop_w!:!crop_h!:%%a:%%b"
					)
					set "RESIZE_REQUIRED=1"
				)
				%DBG% AUTO-CROP final result: !CROP!
			)
		) else if defined CROP_VAL (
			echo(!CROP_VAL! | findstr /i /c:"crop=" /c:"scale_cuda" >nul && set "RESIZE_REQUIRED=1"
		)

		set "crop_x=0" & set "crop_y=0"
		if defined CROP_VAL (
			for /f "tokens=3,4 delims=:" %%a in ("!CROP_VAL!") do (
				set "crop_x=%%a"
				set "crop_y=%%b"
			)
		)
		%DBG% RUN_PROBE: RC=!PROBE_OK!
		%DBG% RUN_PROBE: FFmpeg_Crop=!crop_x!:!crop_y!
		%DBG% RUN_PROBE: FFmpeg_Res=!crop_w!:!crop_h!

		set "VF_CHAIN="
		if defined CROP_VAL set "VF_CHAIN=!CROP_VAL!"
		if defined FILTER (
			if defined VF_CHAIN (set "VF_CHAIN=!VF_CHAIN!,!FILTER!") else (set "VF_CHAIN=!FILTER!")
		)
		if defined MODE (
			if defined VF_CHAIN (set "VF_CHAIN=!VF_CHAIN!,!MODE!") else (set "VF_CHAIN=!MODE!")
		)

		set "VF_PARAM="
		if defined VF_CHAIN (
			if defined RESIZE_PARAM (
				set "VF_PARAM=-vf !VF_CHAIN!,!RESIZE_PARAM!"
			) else (
				set "VF_PARAM=-vf !VF_CHAIN!"
			)
		) else if defined RESIZE_PARAM (
			set "VF_PARAM=-vf !RESIZE_PARAM!"
		)

		setlocal DisableDelayedExpansion
		powershell -command "write-output ('file:///' + (get-item '%%~dpI').FullName.Replace('\', '/') -replace [char]34, [char]7 -replace ' ', '%%20' -replace '#', '%%23' -replace [char]39, '%%27' -replace '!', '%%21' -replace '\(', '%%28' -replace '\)', '%%29')"
		endlocal

		mediainfo --Inform="General;%%Duration/String2%% - %%FileSize/String4%%" "%%I"

		%DBG% FFmpeg parameters:
		%DBG%   CROP   = "!CROP_VAL!"
		%DBG%   FILTER = "!VF_PARAM!"
		%DBG%   AUDIO  = "!AUDIO!"

		if not defined SKIP_FILE (
            ffmpeg %FF_FLAGS% !DECODER_PARAM! -i "%%I" -map 0 -c:v %ENCODER% -profile:v %PROFILE% -level:v auto -rc:v vbr -cq:v !QUALITY! !PRESET! -multipass:v fullres -spatial_aq:v 1 -temporal_aq:v 1 -aq-strength:v 10 -rc-lookahead:v 24 !TUNING! !B_REF! !VF_PARAM! !AUDIO_ARGS! -c:s copy -map_metadata 0 -map_chapters 0 "_Converted\%%~nI.mkv"
			if errorlevel 1 exit /b !ERRORLEVEL!

			if exist "_Converted\%%~nI.mkv" (
				if "%EDIT_TAGS%"=="1" call :EDIT_TAGS "_Converted\%%~nI.mkv"
				call :REMUX_IF_NEEDED "%%I" "_Converted\%%~nI.mkv"
			)

			for /L %%X in (5,-1,1) do (
				echo Waiting for %%X seconds...
				timeout /t 1 >nul
			)
			echo.
		)
	)
)
if "%FOUND%"=="0" (
	echo No files found.
) else (
	powershell -command "$o=ls . -inc *.mkv,*.mp4,*.avi,*.webm; $s=0; $d=0; foreach($f in $o){$c='_Converted\'+$f.Name; if(test-path $c){$s+=$f.Length; $d+=(ls $c).Length}}; if($s -gt 0){write-host ('[INFO] Savings: {0:N2} GB ({1:P1})' -f (($s-$d)/1GB), (($s-$d)/$s)) -fg Green}"
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

:VALIDATE_ONE
if "%~1"=="" exit /b
set "VALID=0"
for %%A in (!%2!) do if /i "%~1"=="%%A" set "VALID=1"
if "!VALID!"=="0" (
	set "ERR_MSG=Invalid %3 '%~1' at position %4. Valid values: [!%2: =|!]"
	set "PARAM_ERR=1"
	echo %ESC%[91mERROR: !ERR_MSG!%ESC%[0m
)
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

for /f "usebackq delims=" %%V in (`cmd /c mediainfo "--Inform=Video;%%Width%%x%%Height%%" "!FILE!" 2^>nul`) do %DBG% EDIT_TAGS: mediainfo_video=%%V
for /f "usebackq delims=" %%V in (`cmd /c mediainfo "--Inform=General;%%VideoCount%%" "!FILE!" 2^>nul`) do %DBG% EDIT_TAGS: mediainfo_video_count=%%V
for /f "usebackq delims=" %%V in (`cmd /c mediainfo "--Inform=General;%%AudioCount%%" "!FILE!" 2^>nul`) do %DBG% EDIT_TAGS: mediainfo_audio_count=%%V
for /f "usebackq delims=" %%V in (`cmd /c mediainfo "--Inform=General;%%TextCount%%" "!FILE!" 2^>nul`) do %DBG% EDIT_TAGS: mediainfo_text_count=%%V
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
set "FF_STREAMS="
set "MI_VIDEO_COUNT="

for /f "usebackq" %%N in (`ffprobe -v error -show_entries format^=nb_streams -of default^=noprint_wrappers^=1:nokey^=1 "!FILE!" 2^>nul`) do set "FF_STREAMS=%%N"

for /f "usebackq" %%V in (`mediainfo "--Inform=General;%%VideoCount%%" "!FILE!" 2^>nul`) do set "MI_VIDEO_COUNT=%%V"

%DBG% REMUX_IF_NEEDED: file=!FILE! source=!SOURCE! ff_streams=!FF_STREAMS! mi_video=!MI_VIDEO_COUNT!

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

:APPLY_DYNAMIC_AUDIO
set "AUDIO_ARGS="
set /a "IDX_TARGET=0"
set "SOURCE_FILE=%~1"
set "TARGET_CODEC=%~2"
if "!TARGET_CODEC!"=="" set "TARGET_CODEC=ac3"

if /i "!TARGET_CODEC!"=="ac3"  (set "BR_LOW=192k" & set "BR_HIGH=384k")
if /i "!TARGET_CODEC!"=="aac"  (set "BR_LOW=128k" & set "BR_HIGH=256k")
if /i "!TARGET_CODEC!"=="eac3" (set "BR_LOW=320k" & set "BR_HIGH=640k")

for /f "usebackq tokens=1,2 delims=," %%A in (`ffprobe -hide_banner -v error -select_streams a -show_entries stream^=codec_name^,channels -of csv^=p^=0 "!SOURCE_FILE!"`) do (
	set "CUR_CODEC=%%A"
	set "CUR_CHANNELS=%%B"
	
	if !CUR_CHANNELS! LEQ 2 (set "BITRATE=!BR_LOW!") else (set "BITRATE=!BR_HIGH!")
	
	if /i "!CUR_CODEC!"=="!TARGET_CODEC!" (
		set "AUDIO_ARGS=!AUDIO_ARGS! -c:a:!IDX_TARGET! copy"
	) else (
		set "AUDIO_ARGS=!AUDIO_ARGS! -c:a:!IDX_TARGET! !TARGET_CODEC! -b:a:!IDX_TARGET! !BITRATE!"
	)
	set /a "IDX_TARGET+=1"
)
exit /b

:RUN_PROBE
setlocal
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

powershell.exe -executionpolicy bypass -file "%PS_SCRIPT%" "%~1" -SetFile "%PS_SET_FILE%" -StatusFile "%PS_STATUS_FILE%"

set "RC=%ERRORLEVEL%"

if exist "%PS_SET_FILE%" call "%PS_SET_FILE%"

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
set "USAGE_PARAMS=^<encoder^> [audio=ac3] [quality=26] [crop=none] [filter=none] [mode=none] [decoder=auto] [chkenc=true]"
set "EXAMPLE_PARAMS=hevc ac3 auto auto none none auto false"
set "EXAMPLE_PARAMS2=hevc ac3 auto none gauss deint"
if defined CALLER_NAME (
    set "COMMAND=%CALLER_NAME%"
) else (
    set "COMMAND=%~n0"
)
echo Usage: %COMMAND% %USAGE_PARAMS%
echo.
call :PRINT_TOK "encoder" "(required)"  TOK_ENCODER
call :PRINT_TOK "audio"   "(def=ac3)"   TOK_AUDIO
call :PRINT_TOK "quality" "(def=26)"    TOK_QUALITY
call :PRINT_TOK "crop"    "(def=none)"  TOK_CROP
call :PRINT_TOK "filter"  "(def=none)"  TOK_FILTER
call :PRINT_TOK "mode"    "(def=none)"  TOK_MODE
call :PRINT_TOK "decoder" "(def=auto)"  TOK_DECODER
call :PRINT_TOK "chkenc"  "(def=true)"  TOK_CHKENC
echo.
echo Example: %COMMAND% ^| %UL%encoder%NO% ^| %UL%audio%NO%   ^| %UL%quality%NO% ^| %UL%crop%NO%    ^| %UL%filter%NO%  ^| %UL%mode%NO%    ^| %UL%decoder%NO% ^| %UL%chkenc%NO%  ^|
echo Example: %COMMAND% ^| hevc    ^| ac3     ^|         ^|         ^|         ^|         ^|         ^|         ^|
echo Example: %COMMAND% ^| hevc    ^| ac3     ^| auto    ^| auto    ^|         ^|         ^|         ^|         ^|
echo Example: %COMMAND% ^| hevc    ^| copy    ^| auto    ^| 1080    ^| ushrp   ^|         ^|         ^|         ^|
echo Example: %COMMAND% ^| hevc    ^| copy    ^| hq      ^| 1080    ^| gauss   ^|         ^| sw      ^| true    ^|
echo Example: %COMMAND% ^| hevc    ^| copy    ^| def     ^| none    ^| none    ^| none    ^| sw      ^| false   ^|
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
set "TOK_ENCODER=def hevc he10 h264 av1 av10"
set "TOK_AUDIO=copy copy1 copy2 copy12 copy23 ac3 aac eac3"
set "TOK_QUALITY=def auto hq uhq lq ulq"
set "TOK_CROP=none auto 696 768 800 804 808 812 816 872 960 1012 1024 1036 1040 720 720p 720f 1080 1080p 1080f 2160 2160p 2160f 1348 1420 1440 1440f 1480 1500 1764 1780 1788 1792 1800 c1 c2 c3 c4 c5 c6"
set "TOK_FILTER=none text reverb deblock edgelevel smooth smooth31 smooth63 nlmeans gauss gauss5 sharp denoise denoisehq artifact artifacthq superres superreshq ushrp ushrpdenoise ushrpdenoisehq ushrpartifact ushrpartifacthq log f1 f2 f3 f4 f5 f6"
set "TOK_MODE=none deint yadif yadifbob double 23fps 25fps 30fps 60fps 29fps 59fps tweak brighter darker lighter vintage linear HDRtoSDR HDRtoSDRR HDRtoSDRM HDRtoSDRH dv dolby-vision"
set "TOK_DECODER=def cuda cuvid vp8 vp9 vpx sw mpeg2 auto"
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
$StandardWidths = @(1800,1792,1788,1780,1764,1500,1480,1440,1420,1348)
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
