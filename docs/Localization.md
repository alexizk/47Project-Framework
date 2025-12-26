# Localization

UI/CLI strings should come from string tables to avoid hardcoded text.

- Default locale: `en-US`
- String tables live in `localization/`
- Fallback: key name if missing

Modules may ship their own string tables under `modules/<id>/localization/`.
