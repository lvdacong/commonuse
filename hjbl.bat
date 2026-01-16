@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: hjbl ^<path^>
    echo Example: hjbl C:\tools\bin
    exit /b 1
)

set "NEW_PATH=%~1"

if not exist "%NEW_PATH%" (
    echo Warning: Path does not exist: %NEW_PATH%
    set /p CONFIRM="Continue anyway? (Y/N): "
    if /i not "!CONFIRM!"=="Y" (
        echo Cancelled.
        exit /b 1
    )
)

for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%b"

echo %USER_PATH% | findstr /i /c:"%NEW_PATH%" >nul
if %errorlevel%==0 (
    echo Path already exists in USER PATH: %NEW_PATH%
    exit /b 0
)

if defined USER_PATH (
    setx PATH "%USER_PATH%;%NEW_PATH%" >nul
) else (
    setx PATH "%NEW_PATH%" >nul
)

if %errorlevel%==0 (
    echo Successfully added to USER PATH: %NEW_PATH%
    echo Please restart your terminal for changes to take effect.
) else (
    echo Failed to add path. PATH may be too long (setx limit: 1024 chars^)
    exit /b 1
)

endlocal
