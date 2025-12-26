# CI Pipeline (skeleton)

Recommended minimal CI steps:

1. Lint / formatting
   - Ensure UTF-8, LF, and EditorConfig compliance (best-effort).

2. Tests
   - Run Pester tests in `/tests`.

3. Validate JSON
   - Validate module manifests and plans against schemas.

4. Build artifacts
   - Create a release zip.
   - Optionally sign plans/bundles and publish signatures.

See `.github/workflows/ci.yml`.
