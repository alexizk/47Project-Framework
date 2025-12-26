# Module Settings UI Binding Spec v1

This document defines how `module.json` declares settings pages and how the Framework renders them consistently.

## 1. Design goals
- Module authors declare *what* settings exist; Framework decides *how* they look.
- Settings are namespaced under `Framework.Modules.<ModuleId>.*`.
- Three-tier storage: policy/machine/user.
- UI is generated from declarative schema, with optional custom panels for advanced modules.

## 2. Settings object (module.json)
A module declares:
- `settings.rootKey`: base prefix for settings keys
- `settings.storageScopes`: mapping of patterns to scope (policy/machine/user)
- `settings.pages`: list of pages

### 2.1 Page schema
Each settings page:
- `id` (string)
- `title` (string)
- `route` (string)
- `groups` (array)

### 2.2 Group schema
Each group:
- `id`, `title`
- `controls` (array)

### 2.3 Control schema
Each control is rendered by type.

Common fields:
- `key` (relative to rootKey)
- `type` (enum)
- `title`, `description`
- `default`
- `scopeHint` (optional override)
- `requiresCapability` (optional)
- `risk` (optional: Safe/Caution/Unsafe)
- `visibleWhen` (optional expression)

Types:
- `toggle` (bool)
- `text` (string)
- `path` (string)
- `number` (int/float)
- `dropdown` (enum)
- `multiselect` (string[])
- `table` (array of objects)
- `button` (action)

## 3. Expressions (visibleWhen)
Small expression language:
- comparisons, boolean ops, key lookups
Example:
- `visibleWhen`: `policy.strictAllowlist == false && user.ui.showAdvanced == true`

## 4. Binding rules
- Full key = `settings.rootKey + '.' + control.key`
- Scope is determined by:
  1) `scopeHint` if present
  2) first matching pattern in `settings.storageScopes`
  3) fallback to `user`

## 5. Validation rules
- All keys must be unique per module.
- Controls requiring capabilities must declare `requiresCapability`.
- Unsafe toggles must carry `risk: Unsafe`.

## 6. Example controls
```json
{
  "id": "apps.settings",
  "title": "AppSCrawler Settings",
  "route": "/apps/settings",
  "groups": [
    {
      "id": "risk",
      "title": "Risk & Safety",
      "controls": [
        { "key": "risk.allowUnsafe", "type": "toggle", "title": "Allow unsafe actions", "default": false, "risk": "Unsafe", "requiresCapability": "cap.software.registry_uninstall_unsafe" },
        { "key": "approval.require", "type": "toggle", "title": "Require plan approval", "default": false, "risk": "Caution" }
      ]
    }
  ]
}
```
