# Module Install / Uninstall

## Install flow (atomic)
1. Acquire artifact (repo sync / local bundle / local folder)
2. Quarantine extract to temp
3. Validate:
   - manifest schema
   - file hashes
   - signature/trust (publisher or hash pin)
4. Stage into final location atomically
5. Write journal entry + optional snapshot

## Uninstall
- Remove module binaries
- Optionally preserve user data (default: preserve)
- Journal entry recorded
