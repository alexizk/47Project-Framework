# Trust Model (v1)

The framework supports a progressive trust model:
- **Unsigned, local-first** for hobby/personal usage
- **Signed plans/bundles/modules** for higher assurance environments

## What can be signed
- Plans: embedded signature block (`signature.alg/kid/sig`)
- Bundles: (v1) structure + plan hash check; (future) signed manifest + payload hashes
- Modules: (future) publisher signing + allowlisted thumbprints

## Capability gating
A module declares required `capabilities` in its manifest. The effective policy grants or denies those capabilities.

- Global grants: `capabilityGrants.global`
- Module-specific grants: `capabilityGrants.modules.<moduleId>`

Unsafe operations should be blocked unless:
- The plan step is marked unsafe and policy `allowUnsafe=true`, and
- Any required capabilities are granted.

## "Optional-but-unsafe"
The pack includes capabilities and examples that are safe-by-default but can be enabled in an "unsafe_all" policy for power users.
