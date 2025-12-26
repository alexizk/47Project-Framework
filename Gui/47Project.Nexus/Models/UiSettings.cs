using System.Text.Json.Serialization;

namespace _47Project.Nexus.Models;

public sealed class UiSettings
{
    [JsonPropertyName("theme")]
    public string Theme { get; set; } = "MatrixCyberMinimal";

    [JsonPropertyName("matrixRainEnabled")]
    public bool MatrixRainEnabled { get; set; } = false;

    // 0.0 - 1.0
    [JsonPropertyName("matrixRainIntensity")]
    public double MatrixRainIntensity { get; set; } = 0.22;

    [JsonPropertyName("autoScrollLogs")]
    public bool AutoScrollLogs { get; set; } = true;
}
