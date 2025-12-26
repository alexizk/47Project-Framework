# Commit Conventions

This repo uses **Conventional Commits** to keep history readable and to enable automated changelogs.

## Format
`<type>(optional-scope): <description>`

Examples:
- `feat(core): add policy simulator`
- `fix(zip): prevent zip-slip path traversal`
- `docs: add plan runner diagrams`
- `chore(ci): run security scan`

## Types
- `feat` – new feature
- `fix` – bug fix
- `docs` – documentation only
- `test` – tests only
- `refactor` – code change that is neither feat nor fix
- `perf` – performance improvement
- `build` – build system / packaging
- `ci` – CI changes
- `chore` – maintenance tasks

## Breaking changes
Use `!` after type/scope, or include a `BREAKING CHANGE:` footer.
