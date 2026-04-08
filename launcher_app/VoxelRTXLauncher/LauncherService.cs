using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text.Json;

namespace VoxelRTXLauncher;

internal sealed class LauncherService
{
    private const string DefaultRepo = "ragnar152743/ragnarNET-5.7";
    private const string ManifestUrlTemplate = "https://raw.githubusercontent.com/{0}/main/launcher/manifest.json";
    private const long MinimumHealthyGameSizeBytes = 100L * 1024L * 1024L;

    private static readonly HttpClient HttpClient = BuildHttpClient();

    private readonly LauncherContract _contract;
    private readonly string _launcherDirectory;
    private readonly string _currentLauncherPath;
    private readonly string _launcherExecutableName;
    private readonly string _bundledGamePath;
    private readonly string _installRoot;
    private readonly string _installStatePath;

    public LauncherService(LauncherContract contract)
    {
        _contract = contract;
        _launcherDirectory = AppContext.BaseDirectory;
        _currentLauncherPath = Environment.ProcessPath ?? Path.Combine(_launcherDirectory, "VoxelRTXLauncher.exe");
        _launcherExecutableName = Path.GetFileName(_currentLauncherPath);
        if (string.IsNullOrWhiteSpace(_launcherExecutableName))
        {
            _launcherExecutableName = "VoxelRTXLauncher.exe";
        }
        _bundledGamePath = Path.Combine(_launcherDirectory, _contract.GameExecutable);
        _installRoot = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs",
            "VoxelRTX"
        );
        _installStatePath = Path.Combine(_installRoot, "install_state.json");
    }

    public string InstalledGamePath => Path.Combine(_installRoot, _contract.GameExecutable);
    public string InstalledLauncherPath => Path.Combine(_installRoot, _launcherExecutableName);

    public string ConfiguredRepository => DefaultRepo;

    public bool HasBundledGame =>
        File.Exists(_bundledGamePath)
        && !string.Equals(
            Path.GetFullPath(_bundledGamePath),
            Path.GetFullPath(InstalledGamePath),
            StringComparison.OrdinalIgnoreCase
        );

    public bool HasInstalledGame => File.Exists(InstalledGamePath);

    public async Task<EnsureInstallResult> EnsureGameReadyAsync(
        IProgress<string>? progress = null,
        CancellationToken cancellationToken = default
    )
    {
        progress?.Report("Verification de l'installation...");
        Directory.CreateDirectory(_installRoot);
        EnsureLauncherInstalled();

        var manifest = await FetchManifestAsync(cancellationToken);
        var installedVersion = GetInstalledVersion();
        var installBroken = await IsInstalledGameBrokenAsync(manifest, cancellationToken);

        if (!HasInstalledGame || installBroken)
        {
            var repairMode = HasInstalledGame && installBroken;
            var status = !HasInstalledGame
                ? "Jeu absent, installation en cours..."
                : "Installation invalide, reparation en cours...";
            progress?.Report(status);

            var downloadResult = await TryInstallFromGitHubAsync(
                manifest,
                progress,
                cancellationToken,
                updateMode: false,
                repairMode: repairMode
            );
            if (downloadResult.Success)
            {
                return downloadResult;
            }

            var bundleResult = TryInstallFromBundle(progress, repairMode);
            if (bundleResult.Success)
            {
                return bundleResult;
            }

            return new EnsureInstallResult
            {
                Success = false,
                ErrorCode = downloadResult.ErrorCode,
                Status = downloadResult.Status,
            };
        }

        var manifestVersion = NormalizeVersion(manifest.Version);
        if (IsVersionNewer(manifestVersion, installedVersion))
        {
            progress?.Report($"Nouvelle version {manifestVersion} detectee, mise a jour...");
            var updateResult = await TryInstallFromGitHubAsync(manifest, progress, cancellationToken, updateMode: true);
            if (updateResult.Success)
            {
                return updateResult;
            }
        }

        progress?.Report("Installation prete.");
        return new EnsureInstallResult
        {
            Success = true,
            Status = string.IsNullOrWhiteSpace(installedVersion)
                ? "Jeu pret."
                : $"Jeu pret. Version {installedVersion}.",
            GamePath = InstalledGamePath,
            InstalledVersion = installedVersion,
        };
    }

    private async Task<LauncherManifest> FetchManifestAsync(CancellationToken cancellationToken)
    {
        var fallback = BuildDefaultManifest();
        var manifestUrl = string.Format(ManifestUrlTemplate, DefaultRepo);

        try
        {
            using var response = await HttpClient.GetAsync(manifestUrl, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return fallback;
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            var manifest = await JsonSerializer.DeserializeAsync<LauncherManifest>(stream, cancellationToken: cancellationToken);
            return NormalizeManifest(manifest, fallback);
        }
        catch
        {
            return fallback;
        }
    }

    private LauncherManifest BuildDefaultManifest()
    {
        var currentVersion = NormalizeVersion(Application.ProductVersion ?? "1.1.0");
        return new LauncherManifest
        {
            ProductName = "Voxel RTX Game",
            Repository = DefaultRepo,
            Version = currentVersion,
            GameDownloadUrl = $"https://github.com/{DefaultRepo}/releases/latest/download/{_contract.GameExecutable}",
            LauncherDownloadUrl = "https://github.com/ragnar152743/ragnarNET-5.7/releases/latest/download/VoxelRTXLauncher.exe",
            Notes = "Launcher GitHub feed configured.",
        };
    }

    private static LauncherManifest NormalizeManifest(LauncherManifest? manifest, LauncherManifest fallback)
    {
        var normalized = manifest ?? new LauncherManifest();
        if (string.IsNullOrWhiteSpace(normalized.ProductName))
        {
            normalized.ProductName = fallback.ProductName;
        }

        if (string.IsNullOrWhiteSpace(normalized.Repository))
        {
            normalized.Repository = fallback.Repository;
        }

        if (string.IsNullOrWhiteSpace(normalized.Version))
        {
            normalized.Version = fallback.Version;
        }

        if (string.IsNullOrWhiteSpace(normalized.GameDownloadUrl))
        {
            normalized.GameDownloadUrl = fallback.GameDownloadUrl;
        }

        if (string.IsNullOrWhiteSpace(normalized.LauncherDownloadUrl))
        {
            normalized.LauncherDownloadUrl = fallback.LauncherDownloadUrl;
        }

        return normalized;
    }

    private async Task<bool> IsInstalledGameBrokenAsync(LauncherManifest manifest, CancellationToken cancellationToken)
    {
        if (!HasInstalledGame)
        {
            return true;
        }

        var info = new FileInfo(InstalledGamePath);
        if (!info.Exists || info.Length < MinimumHealthyGameSizeBytes)
        {
            return true;
        }

        if (string.IsNullOrWhiteSpace(manifest.GameSha256))
        {
            return false;
        }

        var installedHash = await ComputeSha256Async(InstalledGamePath, cancellationToken);
        return !string.Equals(
            installedHash,
            manifest.GameSha256.Trim(),
            StringComparison.OrdinalIgnoreCase
        );
    }

    private async Task<EnsureInstallResult> TryInstallFromGitHubAsync(
        LauncherManifest manifest,
        IProgress<string>? progress,
        CancellationToken cancellationToken,
        bool updateMode = false,
        bool repairMode = false
    )
    {
        if (string.IsNullOrWhiteSpace(manifest.GameDownloadUrl))
        {
            return new EnsureInstallResult
            {
                Success = false,
                ErrorCode = "LAUNCH-INSTALL-001",
                Status = "GitHub ne fournit pas encore d'asset de jeu telechargeable.",
            };
        }

        var tempPath = Path.Combine(_installRoot, $"{_contract.GameExecutable}.download");
        try
        {
            progress?.Report(updateMode ? "Telechargement de la mise a jour GitHub..." : "Telechargement du jeu depuis GitHub...");
            using var response = await HttpClient.GetAsync(
                manifest.GameDownloadUrl,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken
            );

            if (!response.IsSuccessStatusCode)
            {
                return new EnsureInstallResult
                {
                    Success = false,
                    ErrorCode = "LAUNCH-INSTALL-002",
                    Status = $"GitHub a repondu {((int)response.StatusCode)} pendant le telechargement.",
                };
            }

            await using (var source = await response.Content.ReadAsStreamAsync(cancellationToken))
            await using (var destination = File.Create(tempPath))
            {
                await source.CopyToAsync(destination, cancellationToken);
            }

            var downloadedInfo = new FileInfo(tempPath);
            if (!downloadedInfo.Exists || downloadedInfo.Length < MinimumHealthyGameSizeBytes)
            {
                File.Delete(tempPath);
                return new EnsureInstallResult
                {
                    Success = false,
                    ErrorCode = "LAUNCH-INSTALL-003",
                    Status = "Le telechargement GitHub est incomplet ou invalide.",
                };
            }

            if (!string.IsNullOrWhiteSpace(manifest.GameSha256))
            {
                var downloadedHash = await ComputeSha256Async(tempPath, cancellationToken);
                if (!string.Equals(downloadedHash, manifest.GameSha256.Trim(), StringComparison.OrdinalIgnoreCase))
                {
                    File.Delete(tempPath);
                    return new EnsureInstallResult
                    {
                        Success = false,
                        ErrorCode = "LAUNCH-INSTALL-004",
                        Status = "Le hash GitHub ne correspond pas au build telecharge.",
                    };
                }
            }

            ReplaceInstalledGame(tempPath);
            var version = NormalizeVersion(manifest.Version);
            var installedHashValue = string.IsNullOrWhiteSpace(manifest.GameSha256)
                ? await ComputeSha256Async(InstalledGamePath, cancellationToken)
                : manifest.GameSha256.Trim();

            SaveInstallState(
                new InstallState
                {
                    Version = version,
                    Source = "github",
                    Sha256 = installedHashValue,
                    FileSize = new FileInfo(InstalledGamePath).Length,
                    InstalledAtUtc = DateTimeOffset.UtcNow.ToString("O"),
                }
            );

            return new EnsureInstallResult
            {
                Success = true,
                Status = updateMode
                    ? $"Mise a jour GitHub installee. Version {version}."
                    : repairMode
                        ? $"Jeu repare depuis GitHub. Version {version}."
                        : $"Jeu installe depuis GitHub. Version {version}.",
                GamePath = InstalledGamePath,
                InstalledVersion = version,
                InstalledFromGitHub = !updateMode,
                UpdatedFromGitHub = updateMode,
                RepairedInstall = repairMode,
            };
        }
        catch
        {
            if (File.Exists(tempPath))
            {
                File.Delete(tempPath);
            }

            return new EnsureInstallResult
            {
                Success = false,
                ErrorCode = "LAUNCH-INSTALL-005",
                Status = "Le telechargement GitHub a echoue.",
            };
        }
    }

    private EnsureInstallResult TryInstallFromBundle(IProgress<string>? progress, bool repairMode)
    {
        if (!HasBundledGame)
        {
            return new EnsureInstallResult
            {
                Success = false,
                ErrorCode = "LAUNCH-INSTALL-006",
                Status = "Aucun build local n'est disponible pour installer ou reparer le jeu.",
            };
        }

        try
        {
            progress?.Report(repairMode ? "Reparation depuis le bundle local..." : "Installation depuis le bundle local...");
            Directory.CreateDirectory(_installRoot);
            File.Copy(_bundledGamePath, InstalledGamePath, true);

            var version = NormalizeVersion(Application.ProductVersion ?? "1.1.0");
            var hash = ComputeSha256(InstalledGamePath);
            SaveInstallState(
                new InstallState
                {
                    Version = version,
                    Source = "bundle",
                    Sha256 = hash,
                    FileSize = new FileInfo(InstalledGamePath).Length,
                    InstalledAtUtc = DateTimeOffset.UtcNow.ToString("O"),
                }
            );

            return new EnsureInstallResult
            {
                Success = true,
                Status = repairMode
                    ? $"Jeu repare depuis le bundle local. Version {version}."
                    : $"Jeu installe localement. Version {version}.",
                GamePath = InstalledGamePath,
                InstalledVersion = version,
                InstalledFromBundle = !repairMode,
                RepairedInstall = repairMode,
            };
        }
        catch
        {
            return new EnsureInstallResult
            {
                Success = false,
                ErrorCode = "LAUNCH-INSTALL-007",
                Status = "Le bundle local n'a pas pu installer le jeu.",
            };
        }
    }

    private void ReplaceInstalledGame(string sourcePath)
    {
        Directory.CreateDirectory(_installRoot);
        if (File.Exists(InstalledGamePath))
        {
            File.Delete(InstalledGamePath);
        }

        File.Move(sourcePath, InstalledGamePath, true);
    }

    private void EnsureLauncherInstalled()
    {
        try
        {
            if (string.IsNullOrWhiteSpace(_currentLauncherPath) || !File.Exists(_currentLauncherPath))
            {
                return;
            }

            if (string.Equals(
                Path.GetFullPath(_currentLauncherPath),
                Path.GetFullPath(InstalledLauncherPath),
                StringComparison.OrdinalIgnoreCase
            ))
            {
                return;
            }

            File.Copy(_currentLauncherPath, InstalledLauncherPath, true);
        }
        catch
        {
            // Ignore launcher self-copy failures; the main path still works from the current launcher.
        }
    }

    private string GetInstalledVersion()
    {
        var state = LoadInstallState();
        if (!string.IsNullOrWhiteSpace(state.Version))
        {
            return NormalizeVersion(state.Version);
        }

        return "0.0.0";
    }

    private InstallState LoadInstallState()
    {
        if (!File.Exists(_installStatePath))
        {
            return new InstallState();
        }

        try
        {
            var json = File.ReadAllText(_installStatePath);
            return JsonSerializer.Deserialize<InstallState>(json) ?? new InstallState();
        }
        catch
        {
            return new InstallState();
        }
    }

    private void SaveInstallState(InstallState state)
    {
        Directory.CreateDirectory(_installRoot);
        var json = JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(_installStatePath, json);
    }

    private static async Task<string> ComputeSha256Async(string path, CancellationToken cancellationToken)
    {
        await using var stream = File.OpenRead(path);
        var hash = await SHA256.HashDataAsync(stream, cancellationToken);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    private static string ComputeSha256(string path)
    {
        using var stream = File.OpenRead(path);
        var hash = SHA256.HashData(stream);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    private static HttpClient BuildHttpClient()
    {
        var client = new HttpClient();
        client.DefaultRequestHeaders.UserAgent.Clear();
        client.DefaultRequestHeaders.UserAgent.Add(
            new ProductInfoHeaderValue("VoxelRTXLauncher", "1.1.0")
        );
        client.Timeout = TimeSpan.FromMinutes(30);
        return client;
    }

    private static string NormalizeVersion(string version)
    {
        var normalized = version.Trim();
        if (normalized.StartsWith("v", StringComparison.OrdinalIgnoreCase))
        {
            normalized = normalized[1..];
        }

        return normalized;
    }

    private static bool IsVersionNewer(string candidate, string current)
    {
        var candidateParts = ExtractVersionParts(candidate);
        var currentParts = ExtractVersionParts(current);
        var maxLength = Math.Max(candidateParts.Count, currentParts.Count);

        for (var index = 0; index < maxLength; index++)
        {
            var candidatePart = index < candidateParts.Count ? candidateParts[index] : 0;
            var currentPart = index < currentParts.Count ? currentParts[index] : 0;
            if (candidatePart > currentPart)
            {
                return true;
            }

            if (candidatePart < currentPart)
            {
                return false;
            }
        }

        return !string.IsNullOrWhiteSpace(candidate) && !string.Equals(candidate, current, StringComparison.OrdinalIgnoreCase);
    }

    private static List<int> ExtractVersionParts(string version)
    {
        var parts = new List<int>();
        var digits = "";

        foreach (var character in version)
        {
            if (character >= '0' && character <= '9')
            {
                digits += character;
            }
            else if (!string.IsNullOrWhiteSpace(digits))
            {
                parts.Add(int.Parse(digits));
                digits = "";
            }
        }

        if (!string.IsNullOrWhiteSpace(digits))
        {
            parts.Add(int.Parse(digits));
        }

        if (parts.Count == 0)
        {
            parts.Add(0);
        }

        return parts;
    }
}
