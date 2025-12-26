# Multi-key Signing and Key Rotation

Publishers may have multiple keys:
- active keys (used to sign)
- retired keys (valid for verification)
- revoked keys (must fail verification)

Trust store should record:
- publisherId
- keys[] { keyId, thumbprint, status, validFrom, validTo }
