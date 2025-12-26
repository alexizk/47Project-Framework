# Plan Runner Flow (Mermaid)

```mermaid
flowchart TD
  A[Load plan.json] --> B[Validate schema + hash/spec]
  B --> C[Verify signature/trust]
  C --> D[Resolve effective policy + config]
  D --> E{Mode}
  E -->|WhatIf| F[Simulate steps + policy gates]
  E -->|Apply| G[Create snapshot + journal runId]
  G --> H[Execute steps (idempotent)]
  H --> I{Failure?}
  I -->|No| J[Commit journal + success]
  I -->|Yes| K{ContinueOnError?}
  K -->|Yes| H
  K -->|No| L[Rollback (optional) + finalize journal]
```
