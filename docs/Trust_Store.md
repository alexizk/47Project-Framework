# Trust Store

The trust store controls which publishers / artifacts are trusted.

## Files
- `trust/publishers.json` — allowlist of trusted publishers (by public key path)
- `trust/keys/` — place public keys/certs here

## Modes
- Publisher trust: trust any artifact signed by a trusted publisher
- Pinning: trust a specific artifact hash (SHA-256)

## Default
The default pack ships with an **empty allowlist**. Add publishers intentionally.
