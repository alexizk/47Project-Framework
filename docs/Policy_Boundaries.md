# Policy Boundaries

This document defines risk categories and how "unsafe" features are gated.

## Risk categories

- `safe`
  - Expected to be safe in normal user contexts.

- `unsafe_requires_admin`
  - Performs admin-level operations (HKLM writes, service changes, driver installs, etc.).

- `unsafe_requires_explicit_policy`
  - Potentially disruptive actions even without admin, such as bulk uninstalls,
    network enumeration, aggressive filesystem crawling, or privacy-sensitive collection.

- `blocked`
  - Not allowed (framework should refuse).

## Enforcement model

1. Module declares `riskProfile` in `module.json`.
2. Policy decides what is allowed via:
   - `allowUnsafe` (legacy on/off)
   - `unsafeGates` (fine-grained categories)

## Recommended defaults

- Default policy: allow `safe`, deny all unsafe unless explicitly enabled.
- Developer policy: allow `unsafe_requires_explicit_policy` but still deny `blocked`.

## UI labeling

Anything not `safe` must show an "Unsafe" indicator in Nexus Shell.


## Legacy labels mapping

Some plans/settings may still use `Safe/Caution/Unsafe`.
They map to policy categories as:
- `Safe` → `safe`
- `Caution` → `unsafe_requires_explicit_policy`
- `Unsafe` → `unsafe_requires_admin`
