# Transaction and Journal Format (v1)

Date: 2025-12-26

## Goals
- Provide an **audit trail** of plan runs.
- Enable “resume” and troubleshooting.
- Keep format append-only and easy to parse.

## Journal file
Format: JSON Lines (`.jsonl`)

Required fields per line:
- `ts` (ISO 8601)
- `runId`
- `planId`
- `stepId` (or `null` for run-level events)
- `event` (e.g., `run.start`, `step.start`, `step.end`, `run.end`)
- `status` (e.g., `ok`, `fail`, `skipped`, `denied`)
- `details` (object; step output, error info, hashes, paths touched)

## Transaction record
A run also writes a small summary JSON:
- `run.json` with metadata (versions, policy hash, snapshot id, journal path)

## Security
Journals must avoid secrets. Sensitive values should be redacted or omitted.
