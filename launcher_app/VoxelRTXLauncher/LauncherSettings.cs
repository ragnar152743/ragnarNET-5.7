using System.Text.Json;

namespace VoxelRTXLauncher;

internal sealed class LauncherSettings
{
    public string GitHubRepo { get; set; } = "";

    public static LauncherSettings Load()
    {
        var path = GetSettingsPath();
        if (!File.Exists(path))
        {
            return new LauncherSettings();
        }

        try
        {
            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<LauncherSettings>(
                       json,
                       new JsonSerializerOptions
                       {
                           PropertyNameCaseInsensitive = true,
                       }
                   ) ?? new LauncherSettings();
        }
        catch
        {
            return new LauncherSettings();
        }
    }

    public void Save()
    {
        var path = GetSettingsPath();
        var directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(path, json);
    }

    public static string NormalizeRepo(string repo)
    {
        var normalized = (repo ?? string.Empty).Trim();
        normalized = normalized.Trim('/');
        return normalized;
    }

    private static string GetSettingsPath()
    {
        var root = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "VoxelRTXLauncher"
        );
        return Path.Combine(root, "settings.json");
    }
}
