@echo off
setlocal
set SCRIPT_DIR=%~dp0
echo [47Project] Starting...

REM Prefer pwsh if available (PowerShell 7+), otherwise fall back to Windows PowerShell.
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%start.ps1" %*
) else (
  powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%start.ps1" %*
)

set ERR=%ERRORLEVEL%
if not "%ERR%"=="0" (
  echo [47Project] start.ps1 failed with exit code %ERR%.
) else (
  echo [47Project] Done (exit code 0).
)

echo Press any key to close...
pause >nul
endlocal
