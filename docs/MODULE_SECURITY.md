# Module security (risk, capabilities, trust)

Modules can declare:
- `risk`: safe | caution | unsafe
- `capabilities`: list of capability IDs used by policy gating
- `publisher` / `trust`: optional metadata for display

When a module is run, the framework enforces:
- capability grants
- risk allowance
- external runtime allow/deny

See also: docs/EXTERNAL_MODULES.md
