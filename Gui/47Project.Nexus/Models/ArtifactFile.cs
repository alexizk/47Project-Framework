using System;

namespace _47Project.Nexus.Models;

public sealed record ArtifactFile(
    string Name,
    string FullPath,
    long SizeBytes,
    DateTime LastWriteTimeUtc
);
