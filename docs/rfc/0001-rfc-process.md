# RFC 0001: RFC process

- Status: accepted
- Date: 2025-12-26
- Owners: Project47

## Summary
We use short RFCs to make decisions for changes that affect **schemas**, **plan execution**, **trust**, **policy**, or **public CLI behavior**.

## When an RFC is required
Create an RFC for changes to:
- JSON schema versions or semantics
- Plan step types / runner behavior
- Trust store format, signatures, verification rules
- Policy boundaries and prompting behavior
- New top-level CLI commands / breaking changes

## Process
1. Create a new file `docs/rfc/NNNN-title.md` from the template.
2. Mark status as `draft`.
3. Discuss and iterate.
4. Mark status `accepted` or `rejected`.
5. Update `docs/Compatibility.md` and/or relevant specs when accepted.

## Notes
- Keep RFCs concise. Prefer examples over prose.
- ADRs document **decisions**; RFCs document **proposals** that may become decisions.
