# Idempotency Guide

A step is idempotent if repeated application produces the same end state.

## Preferred patterns
- “Ensure” operations (ensure file exists, ensure registry value equals X)
- Hash comparisons for files
- Pre-checks that read state without side effects

## WhatIf
- Must never mutate state
- Must describe the change that *would* occur
