using System.Text.Json.Serialization;

namespace VoxelRTXLauncher;

internal sealed class LauncherSelfManifest
{
    [JsonPropertyName("product_name")]
    public string ProductName { get; set; } = "Voxel RTX Launcher";

    [JsonPropertyName("repository")]
    public string Repository { get; set; } = "";

    [JsonPropertyName("launcher_version")]
    public string LauncherVersion { get; set; } = "";

    [JsonPropertyName("launcher_download_url")]
    public string LauncherDownloadUrl { get; set; } = "";

    [JsonPropertyName("launcher_sha256")]
    public string LauncherSha256 { get; set; } = "";

    [JsonPropertyName("notes")]
    public string Notes { get; set; } = "";
}
