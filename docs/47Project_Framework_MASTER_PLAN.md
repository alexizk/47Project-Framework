# 47Project Framework — Master Plan A–Z (Master Reference)

**Product name (user-facing):** 47Project Framework  
**Shell codename (internal):** Nexus  
**Timezone reference:** Europe/Bucharest  

---

## 1. Vision
Build a single, iconic Windows launcher (**47Project Framework**) that hosts multiple internal “apps” as **modules** (e.g., AppSCrawler, IdentityKit). Users experience separate workspaces and settings per module, while the platform guarantees consistency, safety controls, trust, and observability.

### 1.1 Success criteria
- One cohesive app experience: fast startup, consistent navigation, module isolation.
- One execution engine path: UI and headless/CLI share the same plan → validate → execute pipeline.
- “Ultimate” power remains available, but **risk is explicit** and **policy controls are enforceable**.
- Offline-first + trusted content model (signed modules/content/plans).
- Diagnostics and supportability are first-class.

### 1.2 Non-goals (v1 defaults)
- Remote takeover/remote control.
- Always-on background service *by default* (service is optional in productized version).
- Forcing enterprise-only restrictions on everyone.

---

## 2. Principles
1. **Monolith distribution, modular architecture**: one launcher, modular internals.
2. **Determinism on demand**: plans/hashes/approval when enabled.
3. **Power with guardrails**: unsafe features are available only via explicit toggles.
4. **Everything observable**: run reports, structured logs, inventory snapshots, diffs.
5. **Offline-first**: caches + signed bundles for disconnected environments.

---

## 3. High-level Architecture
### 3.1 Components
- **Nexus Shell (Framework UI)**
  - Navigation, workspace management, settings host, command palette, trust center, diagnostics center.
- **Framework Core Services**
  - Policy service, trust service, storage service, logging/telemetry service, scheduler service (task-based), module loader.
- **Modules**
  - Each module declares UI pages, settings pages, capabilities, and optional CLI commands.
- **Execution Engine**
  - Plan builder, validator, step runner, report generator (shared by UI + CLI).

### 3.2 Data flow (canonical)
1. Discover/load modules → validate trust/policy.
2. User selects action (UI) or command (CLI).
3. Build plan → canonicalize → hash.
4. Validate plan (policy gates, trust, risk).
5. Execute steps (download → install/update/uninstall → post-check).
6. Generate report + snapshots + diffs → surface results.

---

## 4. Startup Pipeline (Nexus)
### 4.1 Phases (deterministic)
1. **Bootstrap**: initialize paths, logging, minimal UI.
2. **Trust Init**: load embedded public cert(s), initialize verification.
3. **Policy Load**: load HKLM/HKCU + local JSON policy overlays.
4. **Feature Flags Load**: local cache + optional signed remote awareness (read-only).
5. **UI Bootstrap**: build shell, command palette, nav.
6. **Module Discovery**: scan modules, validate manifests, validate signatures.
7. **Remote Awareness (optional)**: advisories/versions/flags (no remote exec).
8. **Ready**: show home dashboard.

### 4.2 Startup performance goals
- Shell visible quickly with lazy module hydration.
- Background indexing throttled.
- Startup profiling panel available in Diagnostics.

---

## 5. Navigation & UX
### 5.1 Shell layout
- Left navigation:
  - **Home**
  - **Modules** (list)
    - AppSCrawler
    - IdentityKit
    - …
  - **Plan Hub**
  - **Diagnostics**
  - **Trust Center**
  - **Framework Settings**

### 5.2 Module workspaces
- Each module provides:
  - Workspace pages (Overview, Operations, History, etc.)
  - A dedicated **Module Settings** section (module-only)
  - Optional **Pop-out window** (still Framework process)

### 5.3 Command Palette (Ctrl+K)
- Global search across:
  - modules, pages, actions, settings, recent runs, docs
- Supports quick actions:
  - “Run last plan”, “Open AppSCrawler Settings”, “Export support bundle”

### 5.4 Workspace system
- Save/restore named layouts (“App Management”, “Diagnostics”, “Identity Ops”).
- Reopen last workspace on launch.
- Crash recovery: offer “resume/discard” unfinished plan view.

---

## 6. Module System
### 6.1 Module manifest v1
- File: `modules/<ModuleId>/module.json` (or embedded later)
- Required sections:
  - Identity: schemaVersion, moduleId, displayName, version, minFrameworkVersion
  - UI: navigation pages, defaultRoute, allowPopOut, icons
  - Settings: rootKey, pages/groups, storageScopes mapping
  - Capabilities: list of capability IDs
  - Risk profile: default risk, unsafe gating
  - Trust: signatureRequired, allowed publishers/thumbprints
  - Dependencies: dependsOn/conflictsWith

### 6.2 Module lifecycle hooks
- OnLoad, OnReady, OnPolicyChanged, OnNetworkStateChanged, OnShutdown

### 6.3 Module SDK (Framework-provided services)
- Logger
- Policy
- Trust verification
- Storage
- Scheduler
- Notifications
- IPC/API client
- UI navigation utilities

### 6.4 Module packaging (optional)
- `.47module` (zip) containing:
  - module.json
  - binaries/assets
  - signature manifest

---

## 7. Capability Catalog v1 (Permissions)
Capabilities are global IDs the Framework enforces.

### 7.1 Examples
- Software: cap.software.install, cap.software.update, cap.software.uninstall, cap.software.msi, cap.software.msix
- Unsafe: cap.software.registry_uninstall_unsafe, cap.module.custom_hooks_unsafe
- Network: cap.download.network, cap.download.proxy, cap.download.certpin
- Policy: cap.policy.read, cap.policy.write_admin
- Observability: cap.logs.write, cap.eventlog.write, cap.diagnostics.bundle

### 7.2 Enforcement UX
- Modules declare requested capabilities.
- Framework shows a “Permissions/Trust” view per module.
- Policy can block module load or block specific actions.

---

## 8. Settings System
### 8.1 Three-tier storage
- **Policy (enforced):** HKLM + policy.json (managed rules)
- **Machine state:** ProgramData (cache, downloads store index, inventory snapshots)
- **User prefs:** HKCU/LocalAppData (UI prefs, defaults)

### 8.2 Settings rendering
- Modules define settings pages in manifest.
- Framework renders them with consistent components.

### 8.3 Settings hygiene
- Settings keys are namespaced: `Framework.Modules.<ModuleId>.*`
- Schema validation for settings.
- Export/import settings per module.

---

## 9. Trust & Supply Chain
### 9.1 Trust goals
- Offline-first, signature-verified content.
- Clear user-facing status.

### 9.2 What can be signed
- Module packages/manifests
- Catalogs/profiles/providers for AppSCrawler
- Plans (optional)
- Feature flags/content manifests (optional)

### 9.3 Trust Center (UX)
- Shows:
  - module signature status
  - publisher info
  - catalog/provider signature status
  - unsafe mode status + why

### 9.4 Offline bundles
- `.47bundle` (zip) containing:
  - modules + catalogs + profiles + docs + flags
  - signed content manifest

---

## 10. Plan Hub (Framework-wide)
Plan Hub is the “heart” of the platform.

### 10.1 Plan format
- Canonical JSON with stable ordering → SHA256 plan hash.
- Includes:
  - steps with previews
  - risk labels
  - policy snapshot hash
  - module hashes

### 10.2 Plan operations
- Preview / Dry-run
- Approve (if policy requires)
- Schedule (Task Scheduler or service-backed)
- Export/import `.47plan`
- Clone/re-run

### 10.3 Scheduling Center
- Without service: create Windows Scheduled Tasks that call Framework CLI with plan hash.
- With service (future): service executes scheduled plans.

---

## 11. Observability & Diagnostics
### 11.1 Logging
- Human log + optional JSONL structured logs.
- Optional Windows Event Log channel.
- Secret redaction rules.

### 11.2 Reports
- Run report artifact includes:
  - plan hash, policy hash, module versions/hashes
  - step outcomes, exit codes, timings
  - download verification status

### 11.3 Support bundle
- One-click zip containing:
  - logs, reports, snapshots, policy, module list, environment info

### 11.4 Crash resilience
- Recovery on next start (unfinished plan resume/discard)
- Clear “last known good” state

---

## 12. Module Spec: AppSCrawler (Ultimate)
AppSCrawler is the flagship “app install/update/uninstall” module.

### 12.1 Providers
- winget
- choco
- MSI provider (msiexec + product code)
- MSIX/Appx provider
- download (EXE/MSI direct)
- portable
- registry uninstall (unsafe)
- custom script provider (unsafe)

### 12.2 Step model
Each step includes:
- Type: Download/Install/Update/Uninstall/Detect/Hook
- Risk: Safe/Caution/Unsafe
- Preview: exact command/intent
- Timeout, retries

### 12.3 Risk policy
- Safe/Caution/Unsafe enforcement:
  - allow / warn / require confirm / block
- Headless requires explicit AllowUnsafe unless policy permits.

### 12.4 Downloads & cache
- Content-addressed cache: `downloads/_store/<sha256>__<filename>`
- Offline mode: cache-only
- Hash enforcement if expected hash present
- Optional Authenticode enforcement

### 12.5 Hooks (gated)
- PreInstall/PostInstall/PreUninstall/PostUninstall
- Preflight checks

### 12.6 Inventory + diffs
Inventory sources:
- registry uninstall entries
- winget list (best-effort)
- choco list
- appx packages
- portable tracked installs
Snapshots before/after run → diff report.

### 12.7 CLI
- `framework47 apps install --profile Work --yes`
- Output: text/json/csv
- Exit codes: success/partial/policy-block/reboot-required/schema-invalid

---

## 13. Module Spec: IdentityKit (Placeholder)
- Defines its own manifest, settings pages, capabilities, plans.
- Integrates with Plan Hub and Diagnostics.

---

## 14. Productization (EXE/MSI) Roadmap
### 14.1 Recommended packaging
- EXE bootstrapper + MSI core
- Optional MSIX for UI (hybrid)

### 14.2 Service-backed mode (ultimate)
- Project47.Service runs as SYSTEM to execute plans and scheduling.
- UI/CLI communicate via named pipe / localhost IPC.

### 14.3 Update strategy
- Signed update manifests.
- Differential updates where possible.
- Rollback support.

---

## 15. Phased Implementation Roadmap
### Phase 0 — Lock spec (this document)
- Finalize manifest schema v1
- Finalize capability catalog v1
- Finalize plan hash canonicalization rules

### Phase 1 — Framework shell MVP
- Nexus shell UI
- Module discovery + manifest validation
- Settings host + module settings pages
- Command palette baseline
- Diagnostics baseline

### Phase 2 — Plan Hub + engine
- Plan object + hashing + approval
- Step model + risk
- Report pipeline

### Phase 3 — AppSCrawler “ultimate core”
- Providers: winget/choco/download/portable
- Add MSI + MSIX/Appx providers
- Inventory snapshots + diff
- Cache/offline + integrity

### Phase 4 — Ultimate polish
- Pop-out windows
- Trust Center + bundle import
- Scheduling Center
- Support bundle generator
- Performance profiling UI

### Phase 5 — Productization (optional)
- MSI/EXE packaging
- Service-backed execution
- Auto-update channels

---

## 16. Decision Locks (so future changes stay sane)
- Product name: 47Project Framework
- Shell codename: Nexus
- Module manifest schema v1 is the contract
- Capability catalog v1 is the contract
- Plan hash canonicalization must remain stable once shipped

---

## 17. Appendix: File formats
### 17.1 `.47plan`
- Canonical JSON plan + metadata + optional signature.

### 17.2 `.47module`
- Zip: module.json + assets/binaries + signature manifest.

### 17.3 `.47bundle`
- Offline distribution bundle with signed content manifest.

---

## 18. Appendix: UX checklists
- Every module has its own Settings page.
- Every plan is previewable.
- Every run produces a report.
- Unsafe actions always labeled and gated.
- Diagnostics export is always one click.
