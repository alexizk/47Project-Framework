# Repository Channels

Repositories can be split into channels:

- `stable`
- `beta`
- `nightly`

## Layout
- `repositories/<repo>/channels/<channel>/packages/<packageId>/<version>/...`
- `repositories/<repo>/channels/<channel>/index.json`

A root `repositories/<repo>/index.json` can contain a `channels` section that mirrors each channel’s package list.

## Generate
- `pwsh -File .\tools\Generate-47RepoIndex.ps1 -RepoRoot .\repositories\local -Channel stable`
