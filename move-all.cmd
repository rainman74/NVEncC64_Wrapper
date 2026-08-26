@echo off & cls & setlocal

:INIT
set "Filme=E:\Videos\#Eltern Filme\"
set "Serien=E:\Videos\#Eltern Serien\"

:MAIN
for %%I in (HQ LQ) do if exist "%%I" (
	pushd "%%I"

	for %%F in (*.mkv *.mp4) do (
		for %%E in (mkv mp4) do (
			if exist "_Converted\%%~nF.%%E" (
				echo %%~nF.%%E | findstr /i "S0 S1" >nul
				if errorlevel 1 (
					move "_Converted\%%~nF.%%E" "%Filme%"
				) else (
					move "_Converted\%%~nF.%%E" "%Serien%"
				)
				del /Q "%%F" 2>NUL
			)
		)
	)

	popd
)

for %%F in (*.mkv *.mp4) do (
	for %%E in (mkv mp4) do (
		if exist "_Converted\%%~nF.%%E" (
			echo %%~nF.%%E | findstr /i "S0 S1" >nul
			if errorlevel 1 (
				move "_Converted\%%~nF.%%E" "%Filme%"
			) else (
				move "_Converted\%%~nF.%%E" "%Serien%"
			)
			del /Q "%%F" 2>NUL
			attrib -h "%%~nF.checked" 2>NUL
			del /Q "%%~nF.checked" 2>NUL
		)
	)
)

if exist "_Converted" (
	pushd "_Converted"

	for %%F in (*.mkv *.mp4) do (
		echo %%F | findstr /i "S0 S1" >nul
		if errorlevel 1 (
			move "%%F" "%Filme%"
		) else (
			move "%%F" "%Serien%"
		)
	)

	popd
)

:END
del /Q "*.checked" 2>NUL
endlocal
exit /b 0
