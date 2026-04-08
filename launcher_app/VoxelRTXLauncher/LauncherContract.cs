using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace VoxelRTXLauncher;

internal sealed class LauncherContract
{
    private const string DefaultLaunchKey = "RAGNAR2026:773883729.8729/575.ID";
    private const string DefaultLaunchSalt = "VoxelRTXStudio.Security.v1";

    [JsonPropertyName("product_name")]
    public string ProductName { get; set; } = "Voxel RTX Game";
    [JsonPropertyName("game_executable")]
    public string GameExecutable { get; set; } = "VoxelRTXGame.exe";
    [JsonPropertyName("launch_key")]
    public string LaunchKey { get; set; } = DefaultLaunchKey;
    [JsonPropertyName("launch_salt")]
    public string LaunchSalt { get; set; } = DefaultLaunchSalt;
    [JsonPropertyName("error_missing_key")]
    public string ErrorMissingKey { get; set; } = "GAME-AUTH-001";
    [JsonPropertyName("error_invalid_key")]
    public string ErrorInvalidKey { get; set; } = "GAME-AUTH-002";
    [JsonPropertyName("error_invalid_token")]
    public string ErrorInvalidToken { get; set; } = "GAME-AUTH-003";
    [JsonPropertyName("error_missing_nonce")]
    public string ErrorMissingNonce { get; set; } = "GAME-AUTH-004";

    public static LauncherContract Load(string baseDirectory)
    {
        var path = Path.Combine(baseDirectory, "launch_contract.json");
        if (!File.Exists(path))
        {
            return CreateDefault();
        }

        try
        {
            var json = File.ReadAllText(path);
            var contract = JsonSerializer.Deserialize<LauncherContract>(
                json,
                new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true,
                }
            );

            return Normalize(contract);
        }
        catch
        {
            return CreateDefault();
        }
    }

    public string BuildToken(string launchKey, string nonce)
    {
        var payload = Encoding.UTF8.GetBytes($"{launchKey}|{nonce}|{LaunchSalt}");
        var hash = SHA256.HashData(payload);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    private static LauncherContract CreateDefault()
    {
        return new LauncherContract();
    }

    private static LauncherContract Normalize(LauncherContract? contract)
    {
        var normalized = contract ?? CreateDefault();

        if (string.IsNullOrWhiteSpace(normalized.ProductName))
        {
            normalized.ProductName = "Voxel RTX Game";
        }

        if (string.IsNullOrWhiteSpace(normalized.GameExecutable))
        {
            normalized.GameExecutable = "VoxelRTXGame.exe";
        }

        if (string.IsNullOrWhiteSpace(normalized.LaunchKey))
        {
            normalized.LaunchKey = DefaultLaunchKey;
        }

        if (string.IsNullOrWhiteSpace(normalized.LaunchSalt))
        {
            normalized.LaunchSalt = DefaultLaunchSalt;
        }

        if (string.IsNullOrWhiteSpace(normalized.ErrorMissingKey))
        {
            normalized.ErrorMissingKey = "GAME-AUTH-001";
        }

        if (string.IsNullOrWhiteSpace(normalized.ErrorInvalidKey))
        {
            normalized.ErrorInvalidKey = "GAME-AUTH-002";
        }

        if (string.IsNullOrWhiteSpace(normalized.ErrorInvalidToken))
        {
            normalized.ErrorInvalidToken = "GAME-AUTH-003";
        }

        if (string.IsNullOrWhiteSpace(normalized.ErrorMissingNonce))
        {
            normalized.ErrorMissingNonce = "GAME-AUTH-004";
        }

        return normalized;
    }
}
