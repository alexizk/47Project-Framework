# Plan Composition (include / extends)

## include
`include` imports one or more plans and **appends** their steps before the current plan’s steps.

## extends
`extends` imports a base plan and merges:
- metadata (current overrides base)
- `targets` (merged)
- `steps` (base steps first, then current)

## Hashing
Composition is resolved **before** hashing; the resolved plan is what gets canonicalized and hashed.
