# Updater Spec (v1)

The framework can update itself from a local zip or a trusted repository.

## Update sources
- Local zip (`.zip`)
- Local repository folder (`repositories/<name>`)
- Future: remote HTTP repository (same index format)

## Requirements
1. Verify the package/bundle hash.
2. If signed, verify signature against trust policy.
3. Perform an atomic swap:
   - extract to temp
   - verify structure
   - swap folder
4. Preserve user data (AppData/ProgramData) unless explicitly requested.

## Rollback
- Keep `previous/` copy for one rollback.
- `47 update rollback` (planned)

## Policy gates
- Updates are blocked if trust verification fails, unless explicit policy permits unsigned updates.


## Safety
- Use safe zip extraction (zip-slip protection)
- Create a pre-update snapshot (includes pack) for rollback
- Apply via atomic swap (move old aside, move new into place)
