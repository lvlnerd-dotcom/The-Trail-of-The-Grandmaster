@echo off
setlocal enabledelayedexpansion

:: ==============================================================================
:: Trail of the Grandmaster - 1-Click Windows Launcher for GitHub Backup
:: ==============================================================================

cd /d "%~dp0"
title Trail of the Grandmaster - GitHub Backup

:: Check common Git Bash installation locations
set "GIT_BASH="

if exist "C:\Program Files\Git\git-bash.exe" (
    set "GIT_BASH=C:\Program Files\Git\git-bash.exe"
) else if exist "C:\Program Files\Git\bin\bash.exe" (
    set "GIT_BASH=C:\Program Files\Git\bin\bash.exe"
) else if exist "C:\Program Files (x86)\Git\git-bash.exe" (
    set "GIT_BASH=C:\Program Files (x86)\Git\git-bash.exe"
) else if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    set "GIT_BASH=C:\Program Files (x86)\Git\bin\bash.exe"
) else if exist "%LOCALAPPDATA%\Programs\Git\git-bash.exe" (
    set "GIT_BASH=%LOCALAPPDATA%\Programs\Git\git-bash.exe"
) else if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" (
    set "GIT_BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
)

:: If not found in common folders, check PATH
if "!GIT_BASH!"=="" (
    for /f "tokens=*" %%i in ('where bash.exe 2^>nul') do (
        set "GIT_BASH=%%i"
        goto :found
    )
    for /f "tokens=*" %%i in ('where git.exe 2^>nul') do (
        set "GIT_PATH=%%~dpi"
        if exist "!GIT_PATH!..\bin\bash.exe" (
            set "GIT_BASH=!GIT_PATH!..\bin\bash.exe"
            goto :found
        )
    )
)

:found
if "!GIT_BASH!"=="" (
    echo.
    echo ======================================================================
    echo [ERROR] Git for Windows / Git Bash was not found on your system.
    echo ======================================================================
    echo.
    echo To use Git and back up your project to GitHub, please install Git:
    echo.
    echo   Download link: https://git-scm.com/download/win
    echo.
    echo During installation, keep the default options recommended by the installer.
    echo Once installed, double-click this script again.
    echo.
    pause
    exit /b 1
)

:: Launch the Git Bash script
echo Starting Git Bash backup...
if "!GIT_BASH:~-12!"=="git-bash.exe" (
    start "" "!GIT_BASH!" -c "./backup_to_github.sh"
) else (
    "!GIT_BASH!" --login -i -c "./backup_to_github.sh"
)
