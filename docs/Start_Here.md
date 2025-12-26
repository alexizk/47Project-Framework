# Start Here (Ultimate Pack)

This pack is meant to remove **project setup friction** so you can go straight into implementing features.

## 5 Decisions That Freeze Architecture (Stop Adding, Start Coding)
These are the *only* decisions you should treat as “frozen” before deep implementation work:

1. **Step taxonomy + schemas are authoritative**  
   Plans must validate against `schemas/plan_v1.schema.json`. New step types require schema + ADR/RFC.

2. **Trust model is mandatory for remote content**  
   - Prefer **publisher trust** (signed repo index / signed bundles).  
   - Allow **hash pinning** for one-off artifacts.  
   See `docs/Trust_Model.md`.

3. **Policy gates are mapped to capabilities**  
   Every step and module action must declare the capability it consumes. Policy decides allowed/denied/prompt/admin.

4. **Storage + precedence**  
   Policy overrides config overrides defaults. Portable/user/machine layout is fixed by `docs/Folder_Layout.md`.

5. **Error taxonomy + exit codes**  
   Every tool/executor uses the same categories + exit codes (`docs/Operator_UX_and_Exit_Codes.md`).

## Quick start
- Run doctor: `pwsh -File .\47.ps1 doctor`
- First-run wizard: `pwsh -File .\tools\Invoke-47FirstRun.ps1`
- Run a plan (WhatIf): `pwsh -File .\47.ps1 plan run .\examples\plans\sample_exec.plan.json whatif`

## Key docs
- Project overview: `docs/Project_Overview.md`
- Roadmap: `docs/Roadmap.md`
- Threat & trust: `docs/Threat_Model.md`, `docs/Trust_Model.md`
- Plan runner: `docs/Plan_Runner_Spec.md`, `docs/Plan_Runner_Implementation_Skeleton.md`

