# Ultimate Pre‑Coding Checklist

Use this as the “final” checklist. When all items are present in the pack, you can **stop adding** and focus on **implementation**.

> Convention: ✅ included (implemented or stubbed with schema+docs); 🔧 implemented; 🧪 tested (Pester); 🪟 Windows-only.

## A. Project structure and single source of truth
1. ✅ Master config precedence (defaults → user → machine → policy)
2. ✅ Single version file (`Framework/version.json`)
3. ✅ Capabilities + permissions registry (cap → gate → reason)
4. ✅ Stable artifact layout contract (runs/logs/cache/snapshots/repos/bundles)

## B. Plan system completeness
5. ✅ Step taxonomy + schemas (spec now, executor later if needed)
6. ✅ Idempotency contract for every step
7. ✅ Plan composition (include/extends)
8. ✅ Secrets handling design + redaction rules
9. ✅ Plan output contract (results + exit codes)

## C. Transactions, rollback, and safety
10. ✅ Transaction model (snapshots + journal)
11. ✅ Quarantine & safe extraction (download/repo/module/bundle)
12. ✅ Policy gates mapped to capabilities
13. ✅ Privacy + redaction + support bundle rules

## D. Repo / marketplace readiness
14. ✅ Repository format v1 (channels + signed index)
15. ✅ Module packaging format (.47bundle + manifest + hashes)
16. ✅ Module install/uninstall lifecycle (atomic + rollback aware)
17. ✅ Dependency resolution spec (module deps + api levels)

## E. Framework core API
18. ✅ Core contracts (context/log/policy/module/step registration)
19. ✅ Error taxonomy + uniform exceptions
20. ✅ Extensibility points (module hooks + settings UI binding stubs)

## F. CLI and UX readiness
21. ✅ Command router conventions (`--json`, `--quiet`, `--verbose`, `--whatif`)
22. ✅ Interactive prompting rules + non-interactive behavior
23. ✅ First-run wizard (portable vs user, safety presets)
24. ✅ Doctor maturity + module-provided checks

## G. Quality gates and DevEx
25. ✅ CI pipeline (tests, analyzer, docs, manifest, security scan)
26. ✅ Integration test harness patterns
27. ✅ Devcontainer + VSCode tasks
28. ✅ Changelog + version bump automation

## H. Documentation completeness
29. ✅ “All info in one place” (Start Here + Project Overview)
30. ✅ Secure module author guide + idempotency guide
31. ✅ Docs-as-tests (example plans validated in CI/tests)

## I. Security hardening (still not enterprise-only)
32. ✅ Restricted mode (policy‑controlled blocks)
33. ✅ Trust UX commands (trust publisher, list, pin hash)
34. ✅ Supply-chain checks (artifact manifest + signed release manifest)

## J. Performance and reliability
35. ✅ Caching rules + expiry (download/repo)
36. ✅ Concurrency policy (limits + executor rules)
37. ✅ Large output handling (disk full output + JSON summary)

## K. Optional “ultimate extras”
38. ✅ Telemetry (opt‑in; local by default)
39. ✅ Localization (string tables; no hardcoded UX text)
40. ✅ Multi-key signing + key rotation model

## Stop adding, start coding
If you feel tempted to add more, require an RFC and justify why it cannot be done as a module or executor later.
