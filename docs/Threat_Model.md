# Threat Model (v1)

This document describes the main threats and mitigations for 47Project Framework.

## Assets
- Plan files (`*.plan.json`)
- Offline bundles (`*.47bundle`)
- Module manifests (`modules/*/module.json`) and module code
- Policy (`policy.json`)
- Logs and diagnostics bundles

## Threats & mitigations
### Plan tampering
**Threat:** A plan is modified to install different software or run unsafe steps.  
**Mitigations:**
- Canonicalization + SHA-256 hashing (`Plan_Canonicalization_Hash_Spec_v1.md`)
- Optional embedded signatures (`tools/Sign-47Plan.ps1`, `tools/Verify-47Signature.ps1`)
- Policy gating of unsafe actions (`examples/policies/*.policy.json`)

### Bundle substitution / payload swap
**Threat:** A `.47bundle` is swapped or payload contents are changed.  
**Mitigations:**
- Bundle manifest includes `planHash`
- `tools/Verify-47Bundle.ps1` recomputes and checks the plan hash
- (Optional future) content hashing for payload items + manifest signature

### Module spoofing
**Threat:** A malicious module is placed in the `modules` directory.  
**Mitigations:**
- Signed modules (optional; trust model supports allowlists)
- Policy-based capability grants per module
- UI warnings for unsafe modules/steps

### Logging leakage
**Threat:** Sensitive data appears in logs/support bundles.  
**Mitigations:**
- Keep logs structured and avoid secrets
- Support bundle exporter is intentionally conservative
- Provide user review before sharing bundles (recommended operational practice)
