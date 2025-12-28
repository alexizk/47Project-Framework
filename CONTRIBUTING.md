# Contributing

Identity Kit aims to stay **single-file**, **safe-by-default**, and **identity-focused**.

---

## Goals

- Keep it primarily an **identity** tool (profile/lock/wallpaper)
- Optional toggles should remain:
  - reversible
  - individually controllable (tri-state)
  - clearly logged
- Prefer best-effort strategies over brittle assumptions
- Keep the UI responsive and readable

---

## Non-goals

- “Tweak everything” system tool
- Permanent services / background agents
- Bundled changes that surprise end users

---

## Development checklist

### UI / XAML
- Validate XAML parses cleanly
- Avoid illegal entities (`&` etc.) or sanitize safely
- Keep contrast usable in dark theme

### PowerShell safety
- No unguarded null references from `FindName()`
- Log every meaningful action
- Avoid breaking `powershell.exe` 5.1 compatibility

### Release hygiene
- Bump version in script header
- Add/refresh changelog entry
- Ensure docs remain accurate

---

## Bug reports

Include:
- the log text (Copy log)
- Windows version/build
- Admin badge (Yes/No)
- Mode (Portable/Standard)
- steps to reproduce