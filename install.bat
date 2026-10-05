@echo off
REM ============================================================================
REM  Ovie Programming Language v2.3.0 — Windows Batch Installer
REM  Works by cloning the repo and copying the prebuilt windows-x64 binaries.
REM  No Rust, no GitHub release zip needed.
REM ============================================================================
setlocal enabledelayedexpansion

set "OVIE_VERSION=2.3.0"
set "INSTALL_DIR=C:\Program Files\Ovie"
set "BIN_DIR=%INSTALL_DIR%\bin"
set "GITHUB_REPO=https://github.com/southwarridev/ovie.git"

echo.
echo   ============================================================================
echo   ^|                                                                          ^|
echo   ^|              OVIE PROGRAMMING LANGUAGE v2.3.0                           ^|
echo   ^|              Complete Module System - Full Package                       ^|
echo   ^|              Publisher: Ovie Language Team  ^|  MIT License              ^|
echo   ^|                                                                          ^|
echo   ============================================================================
echo.

REM ── Check for Admin ──────────────────────────────────────────────────────────
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo   [WARN] Not running as Administrator.
    echo   [WARN] Please right-click this file and choose "Run as administrator".
    echo.
    pause
    exit /b 1
)
echo   Running as Administrator: YES
echo.

REM ── Check for Git ────────────────────────────────────────────────────────────
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo   [ERROR] Git is not installed or not in PATH.
    echo   [ERROR] Download Git from: https://git-scm.com/download/win
    echo   [ERROR] Install it, then re-run this installer.
    echo.
    pause
    exit /b 1
)

echo   Install directory : %INSTALL_DIR%
echo   Binaries          : %BIN_DIR%
echo.
set /p CONFIRM="  Press ENTER to install or type 'cancel' to exit: "
if /i "!CONFIRM!"=="cancel" exit /b 0
echo.

REM ── Step 1: Find or clone the repo ───────────────────────────────────────────
echo   [1/5] Locating Ovie source...

set "REPO_ROOT="
set "TEMP_CLONE="

REM If this script sits inside the cloned repo, windows-x64\bin\oviec.exe will
REM be right next to it. Check that first — no internet needed.
if exist "%~dp0windows-x64\bin\oviec.exe" (
    set "REPO_ROOT=%~dp0"
    echo   [OK] Using local repo at %~dp0
) else (
    REM Fresh PC — clone from GitHub
    set "TEMP_CLONE=%TEMP%\ovie-install"
    if exist "!TEMP_CLONE!" rmdir /s /q "!TEMP_CLONE!" >nul 2>&1
    echo   [>>] Cloning from GitHub (this takes ~30 seconds)...
    git clone --depth 1 "%GITHUB_REPO%" "!TEMP_CLONE!"
    if !errorlevel! neq 0 (
        echo   [ERROR] git clone failed. Check your internet connection.
        pause
        exit /b 1
    )
    set "REPO_ROOT=!TEMP_CLONE!"
    echo   [OK] Cloned to !TEMP_CLONE!
)

set "SRC=%REPO_ROOT%windows-x64"

REM Sanity-check
if not exist "%SRC%\bin\oviec.exe" (
    echo   [ERROR] Cannot find windows-x64\bin\oviec.exe in the repo.
    echo   [ERROR] The repo layout may have changed.
    pause
    exit /b 1
)

REM ── Step 2: Create directories ───────────────────────────────────────────────
echo.
echo   [2/5] Creating install directories...
for %%D in ("%INSTALL_DIR%" "%BIN_DIR%" "%INSTALL_DIR%\std" "%INSTALL_DIR%\examples" "%INSTALL_DIR%\docs") do (
    if not exist "%%~D" mkdir "%%~D" >nul 2>&1
)
echo   [OK] Directories created at %INSTALL_DIR%

REM ── Step 3: Copy binaries ────────────────────────────────────────────────────
echo.
echo   [3/5] Copying binaries...
copy /y "%SRC%\bin\oviec.exe" "%BIN_DIR%\oviec.exe" >nul
echo   [OK] oviec.exe installed

if exist "%SRC%\ovie.exe" (
    copy /y "%SRC%\ovie.exe" "%BIN_DIR%\ovie.exe" >nul
) else (
    copy /y "%BIN_DIR%\oviec.exe" "%BIN_DIR%\ovie.exe" >nul
)
echo   [OK] ovie.exe installed

REM ── Step 4: Copy stdlib, examples, docs ──────────────────────────────────────
echo.
echo   [4/5] Copying standard library, examples and docs...
if exist "%SRC%\std"      xcopy /e /y /q "%SRC%\std\*"      "%INSTALL_DIR%\std\"      >nul 2>&1
if exist "%SRC%\examples" xcopy /e /y /q "%SRC%\examples\*" "%INSTALL_DIR%\examples\" >nul 2>&1
if exist "%SRC%\docs"     xcopy /e /y /q "%SRC%\docs\*"     "%INSTALL_DIR%\docs\"     >nul 2>&1

for %%F in (README.md LICENSE RELEASE_NOTES_v2.3.md ovie.png ovie.svg ovie.toml.template) do (
    if exist "%SRC%\%%F" copy /y "%SRC%\%%F" "%INSTALL_DIR%\%%F" >nul 2>&1
)
echo   [OK] Files copied

REM ── Step 5: Add to PATH ───────────────────────────────────────────────────────
echo.
echo   [5/5] Adding %BIN_DIR% to system PATH...
REM Read current system PATH from registry
for /f "usebackq tokens=2,*" %%A in (`reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul`) do set "CURRENT_PATH=%%B"

echo !CURRENT_PATH! | findstr /i /c:"%BIN_DIR%" >nul
if %errorlevel% neq 0 (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path /t REG_EXPAND_SZ /d "!CURRENT_PATH!;%BIN_DIR%" /f >nul 2>&1
    echo   [OK] Added to system PATH
) else (
    echo   [OK] Already in system PATH
)

REM ── Cleanup temp clone ────────────────────────────────────────────────────────
if defined TEMP_CLONE (
    if exist "!TEMP_CLONE!" rmdir /s /q "!TEMP_CLONE!" >nul 2>&1
)

REM ── Verify ────────────────────────────────────────────────────────────────────
echo.
echo   Verifying...
"%BIN_DIR%\oviec.exe" --version 2>&1 | findstr /i "ovie"
if %errorlevel% neq 0 (
    echo   [ERROR] Verification failed — oviec.exe did not run correctly.
    pause
    exit /b 1
)
echo   [OK] Verification passed

REM ── Done ──────────────────────────────────────────────────────────────────────
echo.
echo   ============================================================================
echo   ^|                  INSTALLATION COMPLETE!                                 ^|
echo   ============================================================================
echo.
echo   IMPORTANT: Restart your terminal for PATH changes to take effect.
echo.
echo   Quick start:
echo     oviec --version              ^| Check version
echo     oviec --self-check           ^| Validate installation
echo     oviec run examples\hello.ov  ^| Run hello world
echo     oviec new my-project         ^| Create new project
echo.
echo   Docs: https://southwarridev.github.io/ovie/docs/book/index.html
echo.
pause
exit /b 0
