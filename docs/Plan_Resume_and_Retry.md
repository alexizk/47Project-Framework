# Plan resume and retry

The plan runner supports resuming a previously started run using its `runId` and `journal.jsonl`.

## CLI

Resume (default: Apply):

```powershell
pwsh -File .\47.ps1 plan resume .\examples\plans\sample_install.plan.json <runId> apply
```

Resume and only retry previously failed steps:

```powershell
pwsh -File .\47.ps1 plan resume .\examples\plans\sample_install.plan.json <runId> apply retryfailed
```

## Semantics

- When resuming, the runner reads `journal.jsonl` and remembers the last non-`start` status per `stepId`.
- Normal resume:
  - Steps whose last status is `ok` or `skip` are skipped.
- Retry-failed-only:
  - Only steps whose last status is `error` are executed.
- Steps with no prior entry (or `blocked`) are executed.
