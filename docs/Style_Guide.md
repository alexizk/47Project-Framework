# Style Guide

This repository uses **PSScriptAnalyzer** to keep PowerShell consistent.

## Run
- Check: `pwsh -File .\tools\Invoke-47StyleCheck.ps1`
- Fix (best-effort): `pwsh -File .\tools\Fix-47Style.ps1`

## Notes
- Some rules are not auto-fixable; the fix script will report remaining issues.
