# Launch-47GUI.ps1
# Builds and runs the WPF GUI (requires .NET SDK on Windows).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$sln = Join-Path $root 'Gui\47Project.Nexus.sln'

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
  throw "dotnet SDK not found. Install .NET SDK (net8) and retry."
}

dotnet build $sln -c Release
dotnet run --project (Join-Path $root 'Gui\47Project.Nexus\47Project.Nexus.csproj') -c Release
