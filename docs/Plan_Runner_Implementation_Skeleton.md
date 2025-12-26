# Plan Runner Implementation Skeleton

This pack includes a **working skeleton** of the Plan Runner that is intended to be the final shape of the Framework runner, but with **stub executors** for step types.

## Where the code lives

- `Framework/Core/PlanRunner/47.PlanRunner.psm1`
- Exported through Core: `Framework/Core/47.Core.psm1`
- CLI entrypoint:
  - `./47.ps1 plan run <planPath> [whatif|apply] [policyPath] [nosnapshot] [continue]`
  - Tool wrapper: `tools/Run-47Plan.ps1`

## What is implemented (today)

- Run context (`runId`, run folder, journal + result paths)
- `journal.jsonl` append-only journal (start/end + per-step entries)
- Policy risk gating per step via `Test-47RiskAllowed`
- Pre-run snapshot on `Apply` mode (unless `-NoSnapshot`)
- Default executor registration (stubs for common step types)
- A `WhatIf` mode that produces deterministic "would run" results

## What is intentionally stubbed

The following step types are registered as **stubs** (WhatIf works, Apply throws):

- `exec`
- `copy`
- `download`
- `registry`
- `env`
- `service`
- `task`
- `module.call`

## How to extend (the intended way)

Implement real executors and register them:

- Add executor scripts in: `Framework/Core/PlanRunner/Executors/`
- Replace the default stub registration in `Register-47DefaultStepExecutors`
- Each executor receives: `(context, plan, step, mode)` and returns a hashtable:
  - `status`: `ok | whatif | skipped | blocked | error`
  - `message` (optional)
  - `artifacts` (optional)

## Output contract

A run writes:

- `journal.jsonl` — append-only audit stream (one JSON object per line)
- `result.json` — summarized run results

Both paths are included in the returned object from `Invoke-47PlanRun`.

## Next coding milestone

1. Implement the first real executor: `exec`
2. Add idempotency checks (step declares `ensure` / `check`)
3. Implement `download` with trust verification + quarantine
4. Add resume logic (continue from journal)

