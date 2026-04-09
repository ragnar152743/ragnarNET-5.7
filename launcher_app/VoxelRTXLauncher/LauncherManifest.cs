using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace VoxelRTXLauncher;

internal sealed class LauncherManifest
{
    [JsonPropertyName("product_name")]
    public string ProductName { get; set; } = "Voxel RTX Game";

    [JsonPropertyName("repository")]
    public string Repository { get; set; } = "";

    [JsonPropertyName("version")]
    public string Version { get; set; } = "";

    [JsonPropertyName("game_download_url")]
    public string GameDownloadUrl { get; set; } = "";

    [JsonPropertyName("launcher_download_url")]
    public string LauncherDownloadUrl { get; set; } = "";

    [JsonPropertyName("game_sha256")]
    public string GameSha256 { get; set; } = "";

    [JsonPropertyName("game_parts")]
    public List<LauncherDownloadPart> GameParts { get; set; } = [];

    [JsonPropertyName("minimum_game_size_bytes")]
    public long MinimumGameSizeBytes { get; set; }

    [JsonPropertyName("notes")]
    public string Notes { get; set; } = "";
}
