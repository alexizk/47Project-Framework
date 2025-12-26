# Glossary

This glossary defines the *project terms* used across the 47Project Framework docs, schemas, tools, and code.

## Core objects

**Framework (47Project Framework)**  
The PowerShell-first runtime that loads modules, enforces policy/trust, runs plans, and provides the Nexus Shell UI/CLI.

**Nexus Shell**  
The user-facing launcher surface (menu + CLI). It discovers modules and routes commands through the framework.

**Core**  
Shared framework services (paths/storage, logging, policy, trust, module loader, snapshots, journals, etc.).

**Module**  
A packaged feature with a `module.json` manifest and an entrypoint (e.g., `module.psm1`). Modules may expose commands, settings, and doctor checks.

**Module API level**  
A numeric compatibility level that describes the interface contract between the framework and modules. Increment only on breaking changes to module integration.

**Capability**  
A named permission (e.g., `cap.inventory.read`) that a module *requests* and policy *grants/denies*. Capabilities are declared in a catalog.

**Policy**  
Rules that define what is allowed (capabilities, unsafe gates, prompting behavior, admin requirements, etc.). Policy is the framework’s safety boundary.

**Unsafe gates**  
Explicit policy toggles that unlock risky features (e.g., registry edits, external downloads, running unsigned scripts). “Unsafe” can still be permitted—but only intentionally.

**Plan**  
A declarative workflow document that describes steps to execute (validate → hash → optionally sign → run). Plans are designed to be reproducible and auditable.

**Plan runner**  
The execution engine that interprets a plan, enforces policy/trust, produces a journal, and returns structured results.

**Bundle (`.47bundle`)**  
An offline package format containing plans/modules/assets and manifests/hashes so it can be validated and installed/run without internet.

**Repository (repo)**  
A source of modules/bundles/plans, represented by a signed (or pinned) index document.

**Channel**  
A repo subdivision (e.g., `stable`, `beta`, `nightly`) that controls update cadence and risk tolerance.

## Trust and integrity

**Trust store**  
Local records of allowed publishers/keys and/or pinned artifact hashes. Used to verify signatures and decide what to accept.

**Publisher**  
An identity that signs artifacts (plans, bundles, repo indexes). Publishers are represented by public keys/certificates.

**Hash pinning**  
Trusting a specific artifact by its cryptographic hash (even if it’s not signed).

**Signature verification**  
Checking that an artifact’s signature matches its contents and the signer is trusted.

**Artifact manifest**  
A list of shipped files + their hashes, used for tamper detection and reproducible releases.

**SBOM-lite**  
A lightweight record of dependencies/tools used to build or run the pack.

**Canonical JSON**  
A deterministic JSON normalization process so hashing/signing yields stable results across machines.

## Safety, diagnostics, and operations

**Quarantine / staging**  
A temporary location where downloads/extractions are placed and validated (manifest + hashes + signature) before being “activated”.

**Safe extraction**  
Zip/bundle extraction that blocks path traversal (zip-slip), absolute paths, and other unsafe entries.

**Snapshot**  
A saved point-in-time capture of framework state (config, policy, installed modules, and/or pack contents) enabling rollback.

**Rollback**  
Restoring a previous snapshot to undo a failed update or plan run.

**Journal**  
An append-only record of a plan run (step start/end, status, artifacts touched). Used for auditability and resuming.

**Doctor**  
A diagnostic command/surface that checks environment health (and allows modules to contribute health checks).

## Governance and change management

**ADR (Architecture Decision Record)**  
A small document recording a significant decision and its context, so the team doesn’t re-litigate it later.

**RFC (Request For Comments)**  
A proposal document for changes that impact schemas, execution, trust, policy, or other foundational contracts.

