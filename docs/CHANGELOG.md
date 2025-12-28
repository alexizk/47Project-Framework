# Changelog

## v52 (2025-12-28)
- Fixed PowerShell parser error on Linux/macOS: removed duplicate script param block in Framework/47Project.Framework.ps1 and merged parameters into a single top-level CmdletBinding param block.


## v51 (2025-12-28)
- Added launcher transcript logging to `.runtime/logs/launch_*.log` and global trap to capture silent exits.
- start.cmd prints logs folder path.


## v50 (2025-12-28)
- start.cmd now always pauses so the window doesn't disappear, and prints final exit code.
- start.ps1 now writes a boot transcript to `.runtime/logs/boot_*.log` and passes P47_PWSH_PATH to the launcher for both GUI/CLI.


## v49 (2025-12-28)
- Windows bootstrap: portable ZIP is now the preferred pwsh provisioning path (no admin required).
- Added MSI install logging to TEMP when MSI fallback is used.
- Launcher can use pwsh path passed via P47_PWSH_PATH.


## v48 (2025-12-28)
- Windows bootstrap now provisions pwsh more reliably: winget (with agreements) → MSI from GitHub Releases → portable ZIP fallback.
- Improved pwsh discovery (LocalAppData and Appx package probing) and added debug output.


## v47 (2025-12-28)
- Fixed pwsh discovery on Windows: added Appx package probing and LocalAppData install paths.
- start.ps1 now automatically relaunches under pwsh when available (avoids PS 5.1 strict-mode edge cases).
- winget install now accepts agreements automatically.


## v46 (2025-12-28)
- Fixed launcher bug: removed undefined $pwshExe check and ensured Ensure-Pwsh result is used.
- start.ps1 error handling now prints clean message/stack without triggering strict-mode variable exceptions.


## v45 (2025-12-28)
- Fixed pwsh detection after winget install on Windows PowerShell 5.1 (adds ProgramW6432 probing; handles 32-bit host).
- Removed erroneous Ensure-Pwsh -Root invocation in launcher.
- Cleaned bootstrap scripts (removed placeholder lines) and improved start.cmd to prefer pwsh when present.


## v44 (2025-12-28)
- Fixed launch on Windows PowerShell 5.1: removed $IsWindows usage.
- Launcher now attempts to provision PowerShell 7 automatically (winget, fallback portable download).
- Fixed start.ps1 NoGui invocation.


## v43 (2025-12-28)
- Fixed launcher bootstrap on Windows PowerShell 5.1: replaced $MyInvocation.MyCommand.Path with $PSCommandPath.
- start.cmd now stays open on failure and prints exit code.
- start.ps1 now catches launch errors and prints details.


## v42 (2025-12-28)
- Fixed launcher strict-mode path resolution on Windows PowerShell 5.1 (removed Resolve-Path .Path usage).


## v41 (2025-12-28)
- start.ps1: removed reliance on $IsWindows entirely for compatibility with Windows PowerShell 5.1 strict mode.


## v40 (2025-12-28)
- Fixed start.ps1 on Windows PowerShell 5.1: replaced $IsWindows usage with robust host detection under strict mode.


## v39 (2025-12-28)
- Added Module Updates flow (Store shows installed/update status; Install/Update button).
- Added maintainer release checklist + tag script and GUI buttons.
- Added Windows start.cmd and improved start.ps1 (-Bypass/-Unblock) to reduce MOTW friction.
- Fixed launcher path guard to avoid strict-mode .Path null errors.


## v38 (2025-12-26)
- Added release notes generator (tools/release_notes.ps1) and integrated it into GitHub Releases (body_path).
- Added GUI **Update Center** page for verification, linting, module index builds, and Doctor.
- Added best-effort auto verification at startup when `requireVerifiedRelease` is enabled and `_integrity/` is present.
- Added module lint tool (tools/lint_modules.ps1), current pack verifier (tools/verify_current_pack.ps1), and a richer external tool wrapper (hash pinning + standardized result object).
- Added telemetry-free local run history logging to `LogsRootUser/history.jsonl`.
- Improved module execution safety: unsafe modules force capture mode; PowerShell scripts run in a separate pwsh process with conservative flags.

## v37 (2025-12-26)
- Fixed -SafeMode parameter placement (script-level) and window title indicator.
- Doctor now writes report + fix plan before exiting.


## v36 (2025-12-26)
- Added GitHub Release workflow (tag v* → test → build offline zip → publish release).
- Added Safe Mode (CLI -SafeMode and Settings toggle).
- Added requireVerifiedRelease policy toggle and enforcement.
- Added reset_policy, build_module_index, verify_vendor_pester tools.
- Added GUI Store and Search pages.
- Doctor now emits a fix plan report.


## v35 (2025-12-26)
- Activity page: added buttons to run tests, build offline release, and verify zips.
- Activity output viewer now streams tool stdout/stderr live.


## v34 (2025-12-26)
- Fixed tools/Invoke-47Tests.ps1 state recording and removed placeholder content.
- Improved release_verify_offline to record success/failure state reliably.


## v33 (2025-12-26)
- Activity page upgraded to dashboard last test/release/verify state.
- Tools now record last_test/last_release/last_verify into LogsRootUser/state.


## v32 (2025-12-26)
- CI now uses tools/install_pester.ps1 and caches Pester into tools/.vendor for offline zips.
- Offline release builder embeds cached tooling dependencies (tools/.vendor).
- Added tools/runtime_check.ps1.


## v31 (2025-12-26)
- Support bundle upgraded (captures, dist, module list, effective policy, redaction).
- Offline zip now embeds _integrity (manifest + SHA256SUMS + optional signatures).
- Added tools/release_verify_offline.ps1 and GUI release verification card.
- Added committed vendor cache placeholder under tools/.vendor.


## v30 (2025-12-26)
- Added offline release builder + signing/verification tools.
- Added GitHub Actions CI matrix + release artifact.
- Added GUI Activity page (tail framework.log).
- Added capability grant buttons (writes to policy capabilityGrants.modules).


## v29 (2025-12-26)
- Apps list shows Capabilities count badge.
- Added Apps filters: only external runtimes and only caution/unsafe.


## v28 (2025-12-26)
- Apps list shows runtime/risk badges (colored pills) for faster scanning.


## v15 (2025-12-26)
- Documentation overhaul: added full docs set (INDEX/USAGE/GUI/CLI/CONFIG/TROUBLESHOOTING/SECURITY/DEVELOPMENT).
- Clarified one-click run, installer scripts, safe mode, palette behavior, pack diff/apply workflow.
- Regenerated release manifest.

## v14
- One-click launcher + Windows shortcut installer, portable builder, signing helper.
- Added docs/INSTALL.md and dist_manifest.json.

## v13
- UX: UI state persistence, safe mode, config export/import, startup health gate, pinned palette pages.

## v12
- Smarter command palette (fuzzy + recents) and staged pack diff viewer.

## v11
- Verify page, log-to-file, copy CLI, apply staged pack flow.

(Older changes not exhaustively listed here.)
