# 47Project Nexus (GUI)

This folder contains the WPF GUI for **47Project Framework**.

## Build
From the pack root:

```powershell
dotnet build .\Gui\47Project.Nexus.sln -c Release
```

## Run
```powershell
dotnet run --project .\Gui\47Project.Nexus\47Project.Nexus.csproj -c Release
```

The GUI discovers the pack root by searching upward for `Framework/` and `47.ps1`, then imports:
- `Framework/Core/47.Core.psd1`
- `Framework/Core/PlanRunner/47.PlanRunner.psm1`

## Next steps
- Add real pages: Plans, Modules, Repo, Policy/Trust, Logs, Snapshots, Settings
- Replace placeholder VMs with real implementations that wrap existing `tools/*.ps1` and Core functions
- Add streaming logs + step timeline control
