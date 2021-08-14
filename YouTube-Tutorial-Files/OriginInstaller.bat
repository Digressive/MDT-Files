echo off
%DEPLOYROOT%\Applications\Origin\originsetup.exe /silent
:loop
timeout /t 10 /nobreak
tasklist /fi "imagename eq originthinsetupinternal.exe" |find ":" > nul
if errorlevel 1 goto loop
exit