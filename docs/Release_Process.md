# Release Process

The framework is distributed as a zip. A release should be reproducible and verified.

## Build
`pwsh -File .\tools\Release-47.ps1 -RunStyleCheck -RunDocsBuild`

Outputs to: `dist/`

## Recommended artifacts
- `47Project_Framework_Ultimate_Pack_<tag>.zip`
- `.sha256` checksum file
- (Optional) signature files (publisher key)

## Security
- Prefer signing the **release manifest** (or the zip hash) and verifying against the trust store.
