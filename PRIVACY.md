# Privacy

## Telemetry
This pack does **not** include telemetry. It does not phone home by default.

## Network activity
The framework itself is designed to run offline. Any network activity is only performed if you:
- launch a specific app/module that fetches data, or
- use OS/package managers (e.g., winget) to install dependencies.

## Local data
User state is stored locally under `data/` (favorites, recents, UI state, logs).
