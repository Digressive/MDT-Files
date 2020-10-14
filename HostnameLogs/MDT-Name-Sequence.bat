@echo off
setlocal enabledelayedexpansion

rem ***************************************************************************************
rem SPLTTING COMPUTERNAME: PCBEG=FIRST 8 CHARACTERS(Client-) / PCEND=LAST 2 CHARACTERS(01)
rem CHANGE THIS VARIABLE TO MATCH YOUR NAMING SCHEME.
rem ***************************************************************************************
SET PCBEG=%computername:~0,7%
SET PCEND=%computername:~7,2%

rem ***************************************************************************************
rem FOR MDTSHARE VARIABLE, REPLACE VALUE WITH IP/HOSTNAME OF YOUR MDT SERVER
rem ***************************************************************************************
SET MDTSHARE=Z:\_custom\HostnameLogs
SET PCNAME=%PCBEG%%PCEND%

:START
ECHO CURRENT HOSTNAME IS %COMPUTERNAME%
timeout /t 4 >nul
GOTO LOGCHECK
rem ***************************************************************************************
rem DETERMINE IF A FILE NAMED %COMPUTERNAME%.TXT EXISTS IN THE MDT DEPLOYMENT SHARE
rem ***************************************************************************************

:LOGCHECK
IF EXIST %MDTSHARE%\%COMPUTERNAME%.txt (goto FOUND) else goto UNFOUND
rem ***************************************************************************************
rem IF THE FILE EXISTS, TELL THE USER AND PROCEED TO RETRYLOGCHECK STEP
rem ***************************************************************************************

:FOUND
ECHO A MACHINE WITH THIS HOSTNAME HAS ALREADY BEEN JOINED TO THE DOMAIN
GOTO RETRYLOGCHECK
rem ***************************************************************************************
rem IF THE FILE DOESN'T EXIST, TELL THE USER AND PROCEED TO CREATELOG STEP
rem ***************************************************************************************

:UNFOUND
ECHO NO MACHINE WITH THIS HOSTNAME HAS BEEN JOINED TO THE DOMAIN
TIMEOUT /t 4 >nul
GOTO CREATELOG

:CREATELOG
TYPE nul > %MDTSHARE%\%PCNAME%.txt
IF EXIST %MDTSHARE%\%PCNAME%.txt (goto VERIFY) else goto UNFOUND
rem ***************************************************************************************
rem VERIFY THAT %PCNAME%.TXT NOW EXISTS AND EXIT SCRIPT
rem ***************************************************************************************

:VERIFY
ECHO THE FILE %PCNAME%.txt EXISTS
GOTO END

rem DISPLAY NEXT AVAILABLE HOSTNAME. IF A FILE BY THAT NAME EXISTS, PROCEED TO TRYAGAIN STEP.
IF IT DOESN'T EXIST, RENAME PC TO THAT NAME

:RETRYLOGCHECK
ECHO NEXT AVAILABLE HOSTNAME IS %PCNAME%
TIMEOUT /t 2 >nul
ECHO LOOKING FOR FILE %PCNAME%.TXT.........
TIMEOUT /t 2 >nul
IF EXIST %MDTSHARE%\%PCNAME%.txt (goto TRYAGAIN) else goto CHANGE
rem ***************************************************************************************
rem INCREASE %PCEND% VALUE BY 1 THEN PROCEED TO RETRYLOGCHECK STEP
rem ***************************************************************************************

:TRYAGAIN
SET /a "PCEND=PCEND+1"
SET PCNAME=%PCBEG%0%PCEND%
GOTO RETRYLOGCHECK
rem ***************************************************************************************
rem RENAME MACHINE TO %PCNAME% THEN PROCEED TO DISPLAY STEP IF SUCCESSFUL
rem ***************************************************************************************

:CHANGE
TIMEOUT /t 2 >nul
ECHO ATTEMPTING TO CHANGE HOSTNAME TO %PCNAME%........
TIMEOUT /t 2 >nul
wmic computersystem where name="%COMPUTERNAME%" rename "%PCNAME%" | find /i "return" | find /i "0"
IF !ERRORLEVEL! EQU 0 (goto DISPLAY) else goto ERRORCHECK

:ERRORCHECK
wmic computersystem where name="%COMPUTERNAME%" rename "%PCNAME%" | find /i "return" | find /i "5"
IF !ERRORLEVEL! EQU 0 (goto UAC) else goto UHOH
:UAC
wmic computersystem where name="%COMPUTERNAME%" rename "%PCNAME%" | find /i "return"
ECHO UNABLE TO RENAME THE MACHINE. PLEASE RUN THIS SCRIPT AS ADMINISTRATOR
GOTO END
rem ***************************************************************************************
rem IF THERE IS AN ERROR WHILE RENAMING MACHINE, CHANGE COLOR TO RED, INFORM USER & EXIT
rem ***************************************************************************************

:UHOH
ECHO AN ERROR OCCURRED WHILE TRYING TO RENAME THE MACHINE. PLEASE SEE ERROR LOG
wmic computersystem where name="%COMPUTERNAME%" rename "%PCNAME%" | find /i "return" >
%SYSTEMDRIVE%\RenameErrorLog.txt
GOTO END
rem ***************************************************************************************
rem DISPLAY NEW COMPUTERNAME TO USER AND PROCEED TO CREATELOG STEP
rem ***************************************************************************************

:DISPLAY
SET REG="reg query HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName /v ComputerName | find /i "%PCEND%""
FOR /f "tokens=3 delims= " %%G in ('%REG%') DO echo COMPUTERNAME HAS BEEN CHANGED TO %%G
GOTO CREATELOG
rem ***************************************************************************************
rem EXIT SCRIPT AND PROCEED TO NEXT STEP IN MDT TASK SEQUENCE
rem ***************************************************************************************

:END
ECHO PROCEEDING TO NEXT PHASE OF MDT TASK SEQUENCE
exit