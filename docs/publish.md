# Publishing to GitHub (identity-kit branch)

Recommended branch layout (root):

- `47Apps-IdentityKit.ps1` (stable latest)
- `47Apps-IdentityKit-vX.Y.Z...ps1` (versioned)
- `README.md`
- `docs/`

## Update steps

1. Replace the two script files with the new build.
2. Update `docs/changelog.md` and the version in `README.md` if needed.
3. Commit & push to branch `identity-kit`.

## Suggested commit message

`Identity Kit: v2.4.43 FinalPolish + docs`
