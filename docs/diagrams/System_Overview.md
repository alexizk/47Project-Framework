# System Overview (Mermaid)

```mermaid
flowchart LR
  User[User / Operator] --> CLI[47.ps1 CLI]
  CLI --> Core[Framework Core]
  Core --> Policy[Policy Engine]
  Core --> Trust[Trust + Signatures]
  Core --> Modules[Module Loader]
  Modules --> ModA[Module: AppSCrawler]
  Modules --> ModB[Module: SystemInfo]
  Core --> Plans[Plan Runner]
  Plans --> Journal[Transaction Journal]
  Plans --> Snapshot[Snapshots/Rollback]
  Core --> Repos[Repositories (stable/beta/nightly)]
  Repos --> Bundles[Signed Bundles / Zips]
```
