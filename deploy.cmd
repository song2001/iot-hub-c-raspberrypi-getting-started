@if "%SCM_TRACE_LEVEL%" NEQ "4" @echo off

:: ----------------------
:: KUDU Deployment Script with Functions Package restore
:: Version: 1.0.6
:: ----------------------

:: Prerequisites
:: -------------

:: Verify node.js installed
where node 2>nul >nul
IF %ERRORLEVEL% NEQ 0 (
  echo Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.
  goto error
)

:: Setup
:: -----

setlocal enabledelayedexpansion

SET ARTIFACTS=%~dp0%..\artifacts

IF NOT DEFINED DEPLOYMENT_SOURCE (
  SET DEPLOYMENT_SOURCE=%~dp0%.
)

IF NOT DEFINED DEPLOYMENT_TARGET (
  SET DEPLOYMENT_TARGET=%ARTIFACTS%\wwwroot
)

IF NOT DEFINED NEXT_MANIFEST_PATH (
  SET NEXT_MANIFEST_PATH=%ARTIFACTS%\manifest

  IF NOT DEFINED PREVIOUS_MANIFEST_PATH (
    SET PREVIOUS_MANIFEST_PATH=%ARTIFACTS%\manifest
  )
)

IF NOT DEFINED KUDU_SYNC_CMD (
  :: Install kudu sync
  echo Installing Kudu Sync
  call npm install kudusync -g --silent
  IF !ERRORLEVEL! NEQ 0 goto error

  :: Locally just running "kuduSync" would also work
  SET KUDU_SYNC_CMD=%appdata%\npm\kuduSync.cmd
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Deployment
:: ----------

echo Handling Basic Web Site deployment.

:: KuduSync
IF /I "%IN_PLACE_DEPLOYMENT%" NEQ "1" (
  call :ExecuteCmd "%KUDU_SYNC_CMD%" -v 50 -f "%DEPLOYMENT_SOURCE%" -t "%DEPLOYMENT_TARGET%" -n "%NEXT_MANIFEST_PATH%" -p "%PREVIOUS_MANIFEST_PATH%" -i ".git;.hg;.deployment;deploy.cmd;.eslintrc;.gitignore;.travis.yml;gulpfile.js;LICENSE;README.md;Lesson1;Lesson4;"
  IF !ERRORLEVEL! NEQ 0 goto error
)


echo Handling Function deployment.

cd "%DEPLOYMENT_TARGET%"

:: copy function app files from Lesson 3, then remove Lesson 3
robocopy /S Lesson3\ReceiveDeviceMessages .\ReceiveDeviceMessages
rd /S /Q Lesson3

:: npm packages install
echo "Looking for Node package.json files to install..."
FOR /F %%d in ('DIR /a:d /B') DO ( 
    echo cd %%d
    cd %%d

    IF EXIST "package.json" (
        Echo Installing packages for %%d
        call npm install 
    )

    cd ..
)

:: NuGet package restore
echo "Restoring function packages"

FOR /F %%d in ('DIR "Project.json" /S /B') DO ( 
  call nuget restore %%d -PackagesDirectory %home%\data\Functions\packages\nuget
)


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
goto end

:: Execute command routine that will echo out when error
:ExecuteCmd
setlocal
set _CMD_=%*
call %_CMD_%
if "%ERRORLEVEL%" NEQ "0" echo Failed exitCode=%ERRORLEVEL%, command=%_CMD_%
exit /b %ERRORLEVEL%

:error
endlocal
echo An error has occurred during web site deployment.
call :exitSetErrorLevel
call :exitFromFunction 2>nul

:exitSetErrorLevel
exit /b 1

:exitFromFunction
()

:end
endlocal
echo Finished successfully.