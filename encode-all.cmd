@echo off & cls & setlocal

:MAIN
call nvencc64_wrapper3 hevc ac3 auto auto
call :DIRECTORIES
call :VARIOUS
goto :END

:DIRECTORIES
set dir=HQ			& set params=ac3 hq auto						& call :EXECUTE
set dir=LQ			& set params=ac3 lq auto						& call :EXECUTE
set dir=HEVC		& set params=ac3 auto auto none none hw false	& call :EXECUTE

:VARIOUS
if exist _Various (pushd _Various) else (md _Various)
for %%I in ("*.cmd") do set FileName="%%I"
call %FileName%
popd
goto :EOF

:EXECUTE
if exist %dir% (pushd %dir%) else (md %dir%)
call nvencc64_wrapper3 hevc %params%
popd
goto :EOF

:END
endlocal
exit /b 0
