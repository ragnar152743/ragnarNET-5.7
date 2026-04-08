using System.Text.Json.Serialization;

namespace VoxelRTXLauncher;

internal sealed class InstallState
{
    [JsonPropertyName("version")]
    public string Version { get; set; } = "";

    [JsonPropertyName("source")]
    public string Source { get; set; } = "";

    [JsonPropertyName("sha256")]
    public string Sha256 { get; set; } = "";

    [JsonPropertyName("file_size")]
    public long FileSize { get; set; }

    [JsonPropertyName("installed_at_utc")]
    public string InstalledAtUtc { get; set; } = "";
}
