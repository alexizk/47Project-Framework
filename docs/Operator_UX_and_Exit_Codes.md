# Operator UX and Exit Codes

Date: 2025-12-26

## Output modes
- Default: human-friendly
- `--json`: machine-friendly structured output

## Verbosity flags
- `--quiet`: only errors + final status
- `--verbose`: extra details

## Exit codes (recommended)
- 0: success
- 1: generic failure
- 2: validation failed
- 3: policy denied
- 4: trust verification failed
- 5: environment/prerequisite missing
- 6: timeout
