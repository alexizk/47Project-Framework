# Plan Runner Specification (v1)

Date: 2025-12-26

This document defines the **execution contract** for `47 plan run`.

## Commands
- `47 plan validate <path>`: schema + semantic validation
- `47 plan run <path> [--whatif|--apply] [--continueOnError] [--force] [--json]`
- `47 plan status [--last] [--runId <id>]`

## Modes
- `--whatif`: compute intended changes and produce a journal; **no mutation**
- `--apply`: execute steps

## Step model
Each plan contains an ordered list of steps.

Common step fields:
- `id` (string, unique in plan)
- `type` (string)
- `name` (string, optional)
- `dependsOn` (array of step ids, optional)
- `timeoutSec` (number, optional)
- `retry` (object, optional)
- `when` (condition object, optional)

## Step types (v1 baseline)
- `exec`: run a process/script with controlled environment
- `copy`: copy files with safety checks
- `download`: download to cache with hash verification
- `registry`: set/read registry values (Windows)
- `env`: set environment variables
- `service`: manage Windows services
- `task`: manage scheduled tasks
- `module.call`: call a module-exposed action/command

## Idempotency
Steps should be idempotent. Each step type may define:
- `check`: determines if step is already satisfied
- `apply`: makes changes

## Results and exit codes
A run produces:
- runId
- snapshotId (if created)
- journal path
- step results

Failure taxonomy (recommended):
- validation error
- policy denied
- prerequisite missing
- execution failure
- timeout

See `docs/Operator_UX_and_Exit_Codes.md`.


### Exec step payload

For `type: "exec"`, include an `exec` object:

- `exec.file` (string, required): command to run (absolute, relative to plan folder, or resolvable via PATH).
- `exec.args` (array of strings, optional): arguments.
- `exec.cwd` (string, optional): working directory (defaults to the plan folder).
- `exec.env` (object, optional): environment variables to add/override for the process.
- `exec.timeoutSec` (number, optional): timeout override for this step.
- `exec.okExitCodes` (array of numbers, optional): allowed exit codes (default `[0]`).
- `exec.captureMaxKB` (number, optional): max captured stdout/stderr per stream in JSON results (full output is still written to files).

#### Idempotency check

Steps may include a `check` object. If the check is satisfied, the step is skipped.

Supported checks:

- `check.type: "pathExists"` with `check.path` (path may be relative to plan folder)
- `check.type: "exec"` with `check.exec` (runs only in Apply mode)
  - `check.exec.file` (required), `check.exec.args`, `check.exec.cwd`, `check.exec.timeoutSec`, `check.exec.expectExitCode` (default `0`)

Notes:
- In `WhatIf` mode, `check.type: "exec"` is **not executed** (to avoid side effects).
- In `Apply` mode, full outputs are saved under the run folder: `runs/<runId>/steps/<stepId>/stdout.txt` and `stderr.txt`.


### Download step payload

For `type: "download"`, include a `download` object:

- `download.url` (string, required): remote URL (http/https) **or** a local path (absolute or relative to plan folder) for offline plans.
- `download.dest` (string, optional): destination file path (absolute or relative to plan folder). If omitted, the payload is saved under the run's step artifacts folder.
- `download.sha256` (string, optional): expected SHA256 hex digest. If provided, the download is verified and caching is keyed by hash.
- `download.headers` (object, optional): HTTP headers for remote downloads.
- `download.timeoutSec` (number, optional): remote timeout seconds (default 60 when supported by the host PowerShell).
- `download.useCache` (boolean, optional): use per-user cache (default `true`).
- `download.overwrite` (boolean, optional): overwrite `dest` if it exists (default `false`).
- `download.extract` (boolean, optional): if `true`, treat the downloaded file as a ZIP and extract it safely (zip-slip protected).
- `download.extractTo` (string, required if `extract: true`): directory to extract into.

#### Idempotency check for download

Supported checks:

- `check.type: "pathExists"` with `check.path` (defaults to `download.dest` when omitted)
- `check.type: "fileHashEquals"` with:
  - `check.path` (defaults to `download.dest` when omitted)
  - `check.sha256` (required)

Notes:
- If `download.dest` already exists and `download.overwrite` is `false`, the runner will skip only if `download.sha256` matches the destination; otherwise it fails fast.


## Step type: `copy`

**Purpose:** Copy a file or directory.

```json
{
  "type": "copy",
  "stepId": "copy_1",
  "copy": {
    "source": "relative/or/absolute/source",
    "destination": "relative/or/absolute/dest",
    "ensure": "present",
    "overwrite": true,
    "recurse": true,
    "skipIfSameHash": true
  }
}
```

## Step type: `registry` (Windows)

**Purpose:** Apply idempotent registry operations.

```json
{
  "type": "registry",
  "stepId": "reg_1",
  "registry": {
    "hive": "HKCU",
    "path": "Software\\47Project",
    "action": "setValue",
    "name": "Enabled",
    "valueType": "DWord",
    "value": 1
  }
}
```

## Step type: `module.call`

**Purpose:** Invoke a module action from a plan.

```json
{
  "type": "module.call",
  "stepId": "modcall_1",
  "moduleCall": {
    "moduleId": "mod.systeminfo",
    "action": "summary",
    "args": { }
  }
}
```
