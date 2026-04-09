using System.Text.Json.Serialization;

namespace VoxelRTXLauncher;

internal sealed class LauncherDownloadPart
{
    [JsonPropertyName("url")]
    public string Url { get; set; } = "";

    [JsonPropertyName("sha256")]
    public string Sha256 { get; set; } = "";

    [JsonPropertyName("size_bytes")]
    public long SizeBytes { get; set; }
}
