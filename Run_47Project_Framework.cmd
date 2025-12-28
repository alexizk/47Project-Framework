@echo off
setlocal
set "ROOT=%~dp0"
cd /d "%ROOT%"

REM Layout lock / run location guard
echo %ROOT% | find /I ".zip" >nul
if %errorlevel%==0 (
  echo It looks like you are running from inside a zip path.
  echo Please extract the pack to a normal folder first.
  pause
)


where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%47Project.Framework.Launch.ps1"
  goto :eof
)

echo PowerShell 7 (pwsh) not found.
where winget >nul 2>nul
if %errorlevel%==0 (
  echo Installing PowerShell 7 via winget...
  winget install --id Microsoft.PowerShell --source winget
  echo.
  echo Launching Framework...
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%47Project.Framework.Launch.ps1"
  goto :eof
)

echo Please install PowerShell 7 (pwsh) and run again.
pause
