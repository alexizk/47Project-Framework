# Logging Contract

This document defines how the framework and modules log.

## Locations

Resolved by `Get-47Paths`:

- Logs root: `Paths.LogsRoot`
- Support bundles: `Paths.SupportBundlesRoot`

## Format

Default format is **JSON Lines** (`.jsonl`) per day per component:

- `framework-YYYYMMDD.jsonl`
- `<moduleId>-YYYYMMDD.jsonl`

Each line is a single JSON object.

### Required fields
- `ts` (ISO-8601 UTC)
- `level` (`trace|debug|info|warn|error|fatal`)
- `component` (`framework` or moduleId)
- `eventId` (string, e.g. `FWK0001`, `MOD1001`)
- `message` (string)

### Optional fields
- `data` (object)
- `error` (object: `type`, `message`, `stack`)
- `correlationId` (string)
- `planId` (string)
- `runId` (string)

## Rotation & retention
- Rotate daily by filename.
- Default retention: **14 days** (configurable).
- Max file size: **10 MB** (optional rolling behavior; framework may implement later).

## Event ID guidance
- Framework: `FWK0001`..`FWK9999`
- Modules: `MOD` + a stable numeric range per module (or `MOD.<moduleShort>` prefix).

## Security
- Never log secrets (tokens/passwords).
- Redact file paths only if policy requires (default: keep paths, because support bundles rely on them).
