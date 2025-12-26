# Permissions and Prompting UX Rules

Date: 2025-12-26

## Risk categories
- `safe`: no prompt; allowed by default
- `unsafe_requires_explicit_policy`: blocked unless policy enables
- `unsafe_requires_admin`: requires elevated session
- `blocked`: never allowed

## Interactive vs non-interactive
- Non-interactive mode must never prompt. Deny or follow policy.
- Interactive prompts must be:
  - explicit about what will happen
  - loggable (decision recorded to journal/log)
  - consistent across commands

## Prompt outcomes
- Allow once (run-scoped)
- Always allow (writes to user config/policy if permitted)
- Deny

## Auditability
Every decision must produce a log/journal entry:
- `policy.denied`
- `prompt.allowed`
- `prompt.denied`
