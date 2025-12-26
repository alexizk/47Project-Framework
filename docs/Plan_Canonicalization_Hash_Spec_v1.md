# Plan Canonicalization & Hashing Spec v1

This spec defines how `.47plan` JSON is canonicalized to produce stable hashes across machines and Framework versions.

## 1. Goals
- Stable plan hash for approvals, scheduling, reproducibility.
- Changes to ordering/whitespace do not affect the hash.
- Hash only depends on plan *meaning*.

## 2. Canonical JSON rules
1) UTF-8 encoding without BOM.
2) Normalize line endings to `\n`.
3) Remove insignificant whitespace.
4) Sort all object keys lexicographically (byte-order, invariant culture).
5) Arrays preserve order (arrays are semantically ordered).
6) Numbers:
   - Integers: no leading zeros
   - Floats: normalized representation (recommend storing as strings if precision matters)
7) Dates/times:
   - Always ISO 8601 with `Z` or explicit offset

## 3. Hash input
- Hash the canonical JSON bytes using SHA-256.
- Output as lowercase hex.

## 4. Plan hash fields
Plan object includes:
- `planHash`: hash of the plan *without* `planHash` and `signature` fields.
- `policyHash`: hash of canonical policy snapshot (optional)
- `moduleHashes`: map of moduleId -> hash (optional)

## 5. Signature (optional)
- Sign the canonical JSON bytes (same bytes used for hashing) using RSA-SHA256.
- Store signature in `signature` object:
  - `alg`: `RSA-SHA256`
  - `kid`: key id
  - `sig`: base64 signature

## 6. Compatibility
- Schema version changes must not silently change canonicalization. If canonicalization changes, bump `hashSpecVersion`.
