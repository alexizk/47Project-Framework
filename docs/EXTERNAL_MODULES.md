# External modules (Python / Go / Node / EXE)

The framework is PowerShell-first, but modules can optionally run external tools via `module.json`:

## module.json schema
Use a `run` object:

```json
{
  "moduleId": "demo-python",
  "displayName": "Demo Python",
  "version": "0.1.0",
  "run": {
    "type": "python",
    "entry": "main.py",
    "args": [],
    "cwd": ".",
    "env": {}
  }
}
```

### run.type values
- `pwsh-module`  : import `entrypoint` as a PowerShell module (legacy/default)
- `pwsh-script`  : run a PowerShell script via `pwsh -File`
- `python`       : run `python <entry> ...`
- `node`         : run `node <entry> ...`
- `go`           : run `go run <entry> -- ...`
- `exe`          : run `<entry>` as an executable

## Notes
- External runtimes must be installed and on PATH.
- In the GUI, Apps -> select a module -> Launch executes the module run spec.
- You can add extra args in the Args box (for scripts and external modules).

## Policy controls
External runtime execution can be restricted via user policy:
- Open GUI -> Settings -> Policy
- Or edit the user policy.json at your user data path.

Keys:
- `externalRuntimes.allow`
- `externalRuntimes.allowPython`
- `externalRuntimes.allowNode`
- `externalRuntimes.allowGo`
- `externalRuntimes.allowPwshScript`
- `externalRuntimes.allowExe`

## Hash pinning
Module `run` blocks may optionally include `expectedSha256` to pin the runtime binary used for execution.

Example:
```json
"run": {
  "type": "python",
  "entry": "main.py",
  "expectedSha256": "<sha256 of python.exe or python binary>"
}
```
