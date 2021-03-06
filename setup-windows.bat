@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

SET RESETVARS=https://raw.githubusercontent.com/PredixDev/local-setup/master/resetvars.vbs

GOTO START

:PROCESS_ARGS
IF "%1"=="" (
  ECHO Installing all the tools...
  CALL :INSTALL_EVERYTHING
  GOTO :eof
)
IF NOT "%1"=="" (
  ECHO Installing only tools specified in parameters...
  CALL :INSTALL_NOTHING
)
:loop_process_args
IF "%1"=="" GOTO end_loop_process_args
IF /I "%1"=="/git" SET install[git]=1
IF /I "%1"=="/cf" SET install[cf]=1
IF /I "%1"=="/putty" SET install[putty]=1
IF /I "%1"=="/jdk" SET install[jdk]=1
IF /I "%1"=="/maven" SET install[maven]=1
IF /I "%1"=="/sts" SET install[sts]=1
IF /I "%1"=="/curl" SET install[curl]=1
IF /I "%1"=="/python2" SET install[python2]=1
IF /I "%1"=="/nodejs" SET install[nodejs]=1
SHIFT
GOTO loop_process_args
:end_loop_process_args
GOTO :eof

:GET_DEPENDENCIES
  ECHO Getting Dependencies
  ECHO !RESETVARS!
  @powershell -Command "(new-object net.webclient).DownloadFile('!RESETVARS!','%TEMP%\resetvars.vbs')"
GOTO :eof

:RELOAD_ENV
  "%TEMP%\resetvars.vbs"
  CALL "%TEMP%\resetvars.bat" >$null
GOTO :eof

:CHECK_INTERNET_CONNECTION
ECHO Checking internet connection...
@powershell -Command "(new-object net.webclient).DownloadString('http://www.google.com')" >$null 2>&1
IF NOT !errorlevel! EQU 0 (
  ECHO Unable to connect to internet, make sure you are connected to a network and check your proxy settings if behind a corporate proxy
  exit /b !errorlevel!
)
ECHO OK
GOTO :eof

:INSTALL_CHOCO
where choco >$null 2>&1
IF NOT !errorlevel! EQU 0 (
  ECHO Installing chocolatey...
  @powershell -NoProfile -ExecutionPolicy unrestricted -Command "(iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))) >$null 2>&1" && SET PATH="%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
  CALL :CHECK_FAIL
  CALL :RELOAD_ENV
)
GOTO :eof

:CHOCO_INSTALL
SETLOCAL
SET tool=%1
SET cmd=%1
IF NOT "%2"=="" (
  SET cmd=%2
)
where !cmd! >$null 2>&1
IF NOT !errorlevel! EQU 0 (
  choco install -y --allow-empty-checksums %1
  CALL :CHECK_FAIL
  CALL :RELOAD_ENV
) ELSE (
  ECHO %1 already installed
  ECHO.
)
ENDLOCAL & GOTO :eof

:CHECK_FAIL
IF NOT !errorlevel! EQU 0 (
  ECHO FAILED
  exit /b !errorlevel!
)
GOTO :eof

:INSTALL_NOTHING
SET install[git]=0
SET install[cf]=0
SET install[putty]=0
SET install[jdk]=0
SET install[maven]=0
SET install[sts]=0
SET install[curl]=0
SET install[python2]=0
SET install[nodejs]=0
GOTO :eof

:INSTALL_EVERYTHING
SET install[git]=1
SET install[cf]=1
SET install[putty]=1
SET install[jdk]=1
SET install[maven]=1
SET install[sts]=1
SET install[curl]=1
SET install[python2]=1
SET install[nodejs]=1
GOTO :eof

:START
PUSHD "%~dp0"

ECHO --------------------------------------------------------------
ECHO This script will install tools required for Predix development
ECHO --------------------------------------------------------------

SET git=0
SET cf=1
SET putty=2
SET jdk=3
SET maven=4
SET sts=5
SET curl=6
SET python2=7
SET nodejs=8

CALL :PROCESS_ARGS %*

CALL :CHECK_INTERNET_CONNECTION
CALL :GET_DEPENDENCIES
CALL :INSTALL_CHOCO

IF !install[git]! EQU 1 CALL :CHOCO_INSTALL git

IF !install[cf]! EQU 1 (
  CALL :CHOCO_INSTALL cloudfoundry-cli cf

  SETLOCAL
  IF EXIST "%ProgramFiles(x86)%" (
    SET filename=predix_win64.exe
  ) ELSE (
  SET filename=predix_win32.exe
  )
  ( cf plugins | findstr "Predix" >$null 2>&1 ) || cf install-plugin -f https://github.com/PredixDev/cf-predix/releases/download/1.0.0/!filename!
  ENDLOCAL

  IF NOT !errorlevel! EQU 0 (
    ECHO If you are behind a corporate proxy, set the 'http_proxy' and 'https_proxy' environment variables.
    ECHO Commands to set proxy:
    ECHO set http_proxy="http://<proxy-host>:<proxy-port>"
    ECHO set https_proxy="http://<proxy-host>:<proxy-port>"
    exit /b !errorlevel!
  )
)

IF !install[putty]! EQU 1 CALL :CHOCO_INSTALL putty
IF !install[jdk]! EQU 1 CALL :CHOCO_INSTALL jdk javac
IF !install[maven]! EQU 1 CALL :CHOCO_INSTALL maven mvn
REM TODO - Uncomment once the chocolatey package is fixed
REM IF !install[sts]! EQU 1 CALL :CHOCO_INSTALL springtoolsuite
IF !install[curl]! EQU 1 CALL :CHOCO_INSTALL curl
IF !install[python2]! EQU 1 CALL :CHOCO_INSTALL python2 python

IF !install[nodejs]! EQU 1 CALL :CHOCO_INSTALL nodejs.install node
CALL :RELOAD_ENV
IF !install[nodejs]! EQU 1 (
  where bower >$null 2>&1 && where grunt >$null 2>&1
  IF NOT !errorlevel! EQU 0 (
    npm install -g bower grunt-cli
  )
)

POPD
