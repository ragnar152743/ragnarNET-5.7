using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text.Json;

namespace VoxelRTXLauncher;

internal sealed class LauncherService
{
    private const string DefaultRepo = "ragnar152743/ragnarNET-5.7";
    private const string GameManifestUrlTemplate = "https://raw.githubusercontent.com/{0}/main/distribution/manifests/manifest.json";
    private const string LauncherManifestUrlTemplate = "https://raw.githubusercontent.com/{0}/main/distribution/manifests/launcher_manifest.json";
    private const long DefaultMinimumHealthyGameSizeBytes = 100L * 1024L * 1024L;
    private const long MinimumHealthyLauncherSizeBytes = 5L * 1024L * 1024L;
    private const int CopyBufferSize = 1024 * 1024;

    private static readonly HttpClient HttpClient = BuildHttpClient();

    private readonly LauncherContract _contract;
    private readonly string _launcherDirectory;
    private readonly string _currentLauncherPath;
    private readonly string _launcherExecutableName;
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

        _installRoot = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs",
            "VoxelRTX"
        );
        _installStatePath = Path.Combine(_installRoot, "install_state.json");
    }

    private string? TryResolveBundledGamePath()
    {
        foreach (var candidate in EnumerateBundledGameCandidates())
        {
            if (string.IsNullOrWhiteSpace(candidate) || !File.Exists(candidate))
            {
                continue;
            }

            if (string.Equals(
                Path.GetFullPath(candidate),
                Path.GetFullPath(InstalledGamePath),
                StringComparison.OrdinalIgnoreCase
            ))
            {
                continue;
            }

            return candidate;
        }

        return null;
    }

    private IEnumerable<string> EnumerateBundledGameCandidates()
    {
        var parentDirectory = Directory.GetParent(_launcherDirectory)?.FullName;
        yield return Path.Combine(_launcherDirectory, _contract.GameExecutable);
        yield return Path.Combine(_launcherDirectory, "release", _contract.GameExecutable);
        yield return Path.Combine(_launcherDirectory, "distribution", _contract.GameExecutable);
        yield return Path.Combine(_launcherDirectory, "game", _contract.GameExecutable);

        if (!string.IsNullOrWhiteSpace(parentDirectory))
        {
            yield return Path.Combine(parentDirectory, "distribution", _contract.GameExecutable);
            yield return Path.Combine(parentDirectory, "distribution", "game", _contract.GameExecutable);
            yield return Path.Combine(parentDirectory, "builds", _contract.GameExecutable);
            yield return Path.Combine(parentDirectory, "builds", "release", _contract.GameExecutable);
        }
    }

    public string InstalledGamePath => Path.Combine(_installRoot, _contract.GameExecutable);
    public string InstalledLauncherPath => Path.Combine(_installRoot, _launcherExecutableName);
    public string ConfiguredRepository => DefaultRepo;

    public bool HasBundledGame => TryResolveBundledGamePath() is not null;

    public bool HasInstalledGame => File.Exists(InstalledGamePath);

    private static void ReportStatus(IProgress<LauncherProgressReport>? progress, string message, double? percent = null)
    {
        if (progress is null)
        {
            return;
        }

        progress.Report(percent.HasValue
            ? LauncherProgressReport.Progress(message, percent.Value)
            : LauncherProgressReport.Status(message));
    }

    public async Task<EnsureInstallResult> EnsureGameReadyAsync(
        IProgress<LauncherProgressReport>? progress = null,
        CancellationToken cancellationToken = default,
        bool forceRepair = false
    )
    {
        ReportStatus(progress, "Verification de l'installation...");
        Directory.CreateDirectory(_installRoot);
        EnsureLauncherInstalled();

        var gameManifest = await FetchGameManifestAsync(cancellationToken);
        var launcherManifest = await FetchLauncherManifestAsync(cancellationToken);
        var launcherStatus = await TryRefreshInstalledLauncherAsync(launcherManifest, progress, cancellationToken);
        var installedVersion = GetInstalledVersion();
        var minimumGameSizeBytes = ResolveMinimumGameSizeBytes(gameManifest);
        var installBroken = forceRepair || await IsInstalledGameBrokenAsync(gameManifest, minimumGameSizeBytes, cancellationToken);

        if (!HasInstalledGame || installBroken)
        {
            var repairMode = forceRepair || (HasInstalledGame && installBroken);
            ReportStatus(
                progress,
                !HasInstalledGame
                    ? "Jeu absent, installation en cours..."
                    : "Installation invalide, reparation en cours...",
                4
            );

            var downloadResult = await TryInstallFromGitHubAsync(
                gameManifest,
                minimumGameSizeBytes,
                progress,
                cancellationToken,
                updateMode: false,
                repairMode: repairMode
            );
            if (downloadResult.Success)
            {
                return WithLauncherStatus(downloadResult, launcherStatus);
            }

            var bundleResult = await TryInstallFromBundle(progress, repairMode);
            if (bundleResult.Success)
            {
                return WithLauncherStatus(bundleResult, launcherStatus);
            }

            return new EnsureInstallResult
            {
                Success = false,
                ErrorCode = downloadResult.ErrorCode,
                Status = downloadResult.Status,
                LauncherStatus = launcherStatus,
            };
        }

        var manifestVersion = NormalizeVersion(gameManifest.Version);
        if (IsVersionNewer(manifestVersion, installedVersion))
        {
            ReportStatus(progress, $"Nouvelle version {manifestVersion} detectee, mise a jour...", 4);
            var updateResult = await TryInstallFromGitHubAsync(
                gameManifest,
                minimumGameSizeBytes,
                progress,
                cancellationToken,
                updateMode: true
            );
            if (updateResult.Success)
            {
                return WithLauncherStatus(updateResult, launcherStatus);
            }
        }

        ReportStatus(progress, "Installation prete.", 100);
        return new EnsureInstallResult
        {
            Success = true,
            Status = string.IsNullOrWhiteSpace(installedVersion)
                ? "Jeu pret."
                : $"Jeu pret. Version {installedVersion}.",
            GamePath = InstalledGamePath,
            InstalledVersion = installedVersion,
            LauncherStatus = launcherStatus,
        };
    }

    private async Task<LauncherManifest> FetchGameManifestAsync(CancellationToken cancellationToken)
    {
        var fallback = BuildDefaultGameManifest();
        return await DownloadJsonManifestAsync(
            string.Format(GameManifestUrlTemplate, DefaultRepo),
            fallback,
            cancellationToken,
            NormalizeGameManifest
        );
    }

    private async Task<LauncherSelfManifest> FetchLauncherManifestAsync(CancellationToken cancellationToken)
    {
        var fallback = BuildDefaultLauncherManifest();
        return await DownloadJsonManifestAsync(
            string.Format(LauncherManifestUrlTemplate, DefaultRepo),
            fallback,
            cancellationToken,
            NormalizeLauncherManifest
        );
    }

    private static async Task<TManifest> DownloadJsonManifestAsync<TManifest>(
        string url,
        TManifest fallback,
        CancellationToken cancellationToken,
        Func<TManifest?, TManifest, TManifest> normalizer
    )
    {
        try
        {
            using var response = await HttpClient.GetAsync(url, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return fallback;
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            var manifest = await JsonSerializer.DeserializeAsync<TManifest>(stream, cancellationToken: cancellationToken);
            return normalizer(manifest, fallback);
        }
        catch
        {
            return fallback;
        }
    }

    private LauncherManifest BuildDefaultGameManifest()
    {
        var currentVersion = NormalizeVersion(Application.ProductVersion ?? "1.2.0");
        return new LauncherManifest
        {
            ProductName = "Voxel RTX Game",
            Repository = DefaultRepo,
            Version = currentVersion,
            GameDownloadUrl = $"https://media.githubusercontent.com/media/{DefaultRepo}/main/distribution/game/{_contract.GameExecutable}",
            LauncherDownloadUrl = $"https://media.githubusercontent.com/media/{DefaultRepo}/main/distribution/launcher/VoxelRTXLauncher.exe",
            MinimumGameSizeBytes = DefaultMinimumHealthyGameSizeBytes,
            Notes = "Manifest officiel du jeu.",
        };
    }

    private LauncherSelfManifest BuildDefaultLauncherManifest()
    {
        return new LauncherSelfManifest
        {
            ProductName = "Voxel RTX Launcher",
            Repository = DefaultRepo,
            LauncherVersion = NormalizeVersion(Application.ProductVersion ?? "1.2.0"),
            LauncherDownloadUrl = $"https://media.githubusercontent.com/media/{DefaultRepo}/main/distribution/launcher/VoxelRTXLauncher.exe",
            Notes = "Manifest officiel du launcher.",
        };
    }

    private static LauncherManifest NormalizeGameManifest(LauncherManifest? manifest, LauncherManifest fallback)
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

        normalized.GameParts ??= [];

        if (string.IsNullOrWhiteSpace(normalized.GameDownloadUrl) && normalized.GameParts.Count == 0)
        {
            normalized.GameDownloadUrl = fallback.GameDownloadUrl;
        }

        if (string.IsNullOrWhiteSpace(normalized.LauncherDownloadUrl))
        {
            normalized.LauncherDownloadUrl = fallback.LauncherDownloadUrl;
        }

        if (normalized.MinimumGameSizeBytes <= 0)
        {
            normalized.MinimumGameSizeBytes = fallback.MinimumGameSizeBytes;
        }

        return normalized;
    }

    private static LauncherSelfManifest NormalizeLauncherManifest(LauncherSelfManifest? manifest, LauncherSelfManifest fallback)
    {
        var normalized = manifest ?? new LauncherSelfManifest();
        if (string.IsNullOrWhiteSpace(normalized.ProductName))
        {
            normalized.ProductName = fallback.ProductName;
        }

        if (string.IsNullOrWhiteSpace(normalized.Repository))
        {
            normalized.Repository = fallback.Repository;
        }

        if (string.IsNullOrWhiteSpace(normalized.LauncherVersion))
        {
            normalized.LauncherVersion = fallback.LauncherVersion;
        }

        if (string.IsNullOrWhiteSpace(normalized.LauncherDownloadUrl))
        {
            normalized.LauncherDownloadUrl = fallback.LauncherDownloadUrl;
        }

        return normalized;
    }

    private static long ResolveMinimumGameSizeBytes(LauncherManifest manifest)
    {
        return manifest.MinimumGameSizeBytes > 0 ? manifest.MinimumGameSizeBytes : DefaultMinimumHealthyGameSizeBytes;
    }

    private static EnsureInstallResult WithLauncherStatus(EnsureInstallResult result, string launcherStatus)
    {
        return new EnsureInstallResult
        {
            Success = result.Success,
            ErrorCode = result.ErrorCode,
            Status = result.Status,
            GamePath = result.GamePath,
            InstalledVersion = result.InstalledVersion,
            InstalledFromBundle = result.InstalledFromBundle,
            InstalledFromGitHub = result.InstalledFromGitHub,
            UpdatedFromGitHub = result.UpdatedFromGitHub,
            RepairedInstall = result.RepairedInstall,
            LauncherStatus = launcherStatus,
        };
    }

    private async Task<bool> IsInstalledGameBrokenAsync(
        LauncherManifest manifest,
        long minimumGameSizeBytes,
        CancellationToken cancellationToken
    )
    {
        if (!HasInstalledGame)
        {
            return true;
        }

        var info = new FileInfo(InstalledGamePath);
        if (!info.Exists || info.Length < minimumGameSizeBytes)
        {
            return true;
        }

        if (string.IsNullOrWhiteSpace(manifest.GameSha256))
        {
            return false;
        }

        var installedHash = await ComputeSha256Async(InstalledGamePath, cancellationToken);
        return !string.Equals(installedHash, manifest.GameSha256.Trim(), StringComparison.OrdinalIgnoreCase);
    }

    private async Task<string> TryRefreshInstalledLauncherAsync(
        LauncherSelfManifest manifest,
        IProgress<LauncherProgressReport>? progress,
        CancellationToken cancellationToken
    )
    {
        var manifestVersion = NormalizeVersion(manifest.LauncherVersion);
        var currentVersion = NormalizeVersion(Application.ProductVersion ?? manifestVersion);
        if (!IsVersionNewer(manifestVersion, currentVersion))
        {
            return "Launcher a jour.";
        }

        if (string.IsNullOrWhiteSpace(manifest.LauncherDownloadUrl))
        {
            return "Maj launcher detectee, mais aucun asset n'est fourni.";
        }

        if (string.Equals(
            Path.GetFullPath(_currentLauncherPath),
            Path.GetFullPath(InstalledLauncherPath),
            StringComparison.OrdinalIgnoreCase
        ))
        {
            return $"Launcher {manifestVersion} disponible sur GitHub.";
        }

        var tempPath = Path.Combine(_installRoot, $"{_launcherExecutableName}.download");
        try
        {
            ReportStatus(progress, $"Verification du launcher {manifestVersion}...", 2);
            using var response = await HttpClient.GetAsync(
                manifest.LauncherDownloadUrl,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken
            );
            if (!response.IsSuccessStatusCode)
            {
                return "Launcher distant detecte, mais son telechargement a echoue.";
            }

            await using (var source = await response.Content.ReadAsStreamAsync(cancellationToken))
            await using (var destination = File.Create(tempPath))
            {
                var expectedBytes = response.Content.Headers.ContentLength ?? 0;
                await CopyStreamWithProgressAsync(
                    source,
                    destination,
                    expectedBytes,
                    copiedBytes => ReportWeightedProgress(
                        progress,
                        $"Verification du launcher {manifestVersion}...",
                        copiedBytes,
                        expectedBytes,
                        2,
                        8
                    ),
                    cancellationToken
                );
            }

            var fileInfo = new FileInfo(tempPath);
            if (!fileInfo.Exists || fileInfo.Length < MinimumHealthyLauncherSizeBytes)
            {
                File.Delete(tempPath);
                return "Launcher distant invalide, mise a jour ignoree.";
            }

            if (!string.IsNullOrWhiteSpace(manifest.LauncherSha256))
            {
                var hash = await ComputeSha256Async(tempPath, cancellationToken);
                if (!string.Equals(hash, manifest.LauncherSha256.Trim(), StringComparison.OrdinalIgnoreCase))
                {
                    File.Delete(tempPath);
                    return "Le hash du launcher distant ne correspond pas.";
                }
            }

            File.Move(tempPath, InstalledLauncherPath, true);
            return $"Launcher AppData mis a jour en {manifestVersion}.";
        }
        catch
        {
            if (File.Exists(tempPath))
            {
                File.Delete(tempPath);
            }

            return "Verification launcher effectuee, sans telechargement exploitable.";
        }
    }

    private async Task<EnsureInstallResult> TryInstallFromGitHubAsync(
        LauncherManifest manifest,
        long minimumGameSizeBytes,
        IProgress<LauncherProgressReport>? progress,
        CancellationToken cancellationToken,
        bool updateMode = false,
        bool repairMode = false
    )
    {
        var hasMultipartPayload = manifest.GameParts is { Count: > 0 };
        if (!hasMultipartPayload && string.IsNullOrWhiteSpace(manifest.GameDownloadUrl))
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
            ReportStatus(
                progress,
                updateMode
                    ? "Telechargement de la mise a jour GitHub..."
                    : "Telechargement du jeu depuis GitHub...",
                0
            );
            EnsureInstallDirectory();

            EnsureInstallResult downloadResult;
            if (hasMultipartPayload)
            {
                downloadResult = await DownloadMultipartGameAsync(
                    manifest,
                    tempPath,
                progress,
                cancellationToken
            );
            }
            else
            {
                downloadResult = await DownloadSingleFileGameAsync(
                    manifest,
                    tempPath,
                    progress,
                    cancellationToken
                );
            }

            if (!downloadResult.Success)
            {
                if (File.Exists(tempPath))
                {
                    File.Delete(tempPath);
                }

                var partDirectory = Path.Combine(_installRoot, "download_parts");
                if (Directory.Exists(partDirectory))
                {
                    Directory.Delete(partDirectory, true);
                }

                return downloadResult;
            }

            ReportStatus(progress, "Verification de l'integrite du build...", 96);
            var downloadedInfo = new FileInfo(tempPath);
            if (!downloadedInfo.Exists || downloadedInfo.Length < minimumGameSizeBytes)
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
            ReportStatus(progress, "Installation du build final...", 99);
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

            var partDirectory = Path.Combine(_installRoot, "download_parts");
            if (Directory.Exists(partDirectory))
            {
                Directory.Delete(partDirectory, true);
            }

            return new EnsureInstallResult
            {
                Success = false,
                ErrorCode = "LAUNCH-INSTALL-005",
                Status = "Le telechargement GitHub a echoue.",
            };
        }
    }

    private static EnsureInstallResult BuildDownloadHttpErrorResult(int statusCode, int? partIndex = null, int? totalParts = null)
    {
        var status = partIndex is null || totalParts is null
            ? $"GitHub a repondu {statusCode} pendant le telechargement."
            : $"GitHub a repondu {statusCode} pendant le telechargement de la partie {partIndex}/{totalParts}.";

        return new EnsureInstallResult
        {
            Success = false,
            ErrorCode = "LAUNCH-INSTALL-002",
            Status = status,
        };
    }

    private static EnsureInstallResult BuildDownloadInvalidResult(string message, string errorCode = "LAUNCH-INSTALL-003")
    {
        return new EnsureInstallResult
        {
            Success = false,
            ErrorCode = errorCode,
            Status = message,
        };
    }

    private void EnsureInstallDirectory()
    {
        Directory.CreateDirectory(_installRoot);
    }

    private static async Task CopyStreamWithProgressAsync(
        Stream source,
        Stream destination,
        long expectedBytes,
        Action<long>? onBytesCopied,
        CancellationToken cancellationToken
    )
    {
        var buffer = new byte[CopyBufferSize];
        long totalBytesCopied = 0;
        long nextReportThreshold = CopyBufferSize * 4L;

        while (true)
        {
            var read = await source.ReadAsync(buffer, cancellationToken);
            if (read <= 0)
            {
                break;
            }

            await destination.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
            totalBytesCopied += read;

            if (totalBytesCopied >= nextReportThreshold || (expectedBytes > 0 && totalBytesCopied >= expectedBytes))
            {
                onBytesCopied?.Invoke(totalBytesCopied);
                nextReportThreshold = totalBytesCopied + CopyBufferSize * 4L;
            }
        }

        onBytesCopied?.Invoke(totalBytesCopied);
    }

    private static void ReportWeightedProgress(
        IProgress<LauncherProgressReport>? progress,
        string message,
        long completedBytes,
        long totalBytes,
        double startPercent,
        double endPercent
    )
    {
        if (totalBytes <= 0)
        {
            ReportStatus(progress, message, startPercent);
            return;
        }

        var ratio = Math.Clamp((double)completedBytes / totalBytes, 0d, 1d);
        var percent = startPercent + ((endPercent - startPercent) * ratio);
        ReportStatus(progress, message, percent);
    }

    private async Task<EnsureInstallResult> DownloadSingleFileGameAsync(
        LauncherManifest manifest,
        string destinationPath,
        IProgress<LauncherProgressReport>? progress,
        CancellationToken cancellationToken
    )
    {
        using var response = await HttpClient.GetAsync(
            manifest.GameDownloadUrl,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken
        );
        if (!response.IsSuccessStatusCode)
        {
            return BuildDownloadHttpErrorResult((int)response.StatusCode);
        }

        await using (var source = await response.Content.ReadAsStreamAsync(cancellationToken))
        await using (var destination = File.Create(destinationPath))
        {
            var expectedBytes = response.Content.Headers.ContentLength ?? 0;
            await CopyStreamWithProgressAsync(
                source,
                destination,
                expectedBytes,
                copiedBytes => ReportWeightedProgress(
                    progress,
                    "Telechargement du build jeu...",
                    copiedBytes,
                    expectedBytes,
                    5,
                    95
                ),
                cancellationToken
            );
        }

        return new EnsureInstallResult { Success = true };
    }

    private async Task<EnsureInstallResult> DownloadMultipartGameAsync(
        LauncherManifest manifest,
        string destinationPath,
        IProgress<LauncherProgressReport>? progress,
        CancellationToken cancellationToken
    )
    {
        var partDirectory = Path.Combine(_installRoot, "download_parts");
        Directory.CreateDirectory(partDirectory);
        long totalBytes = 0;
        foreach (var gamePart in manifest.GameParts)
        {
            totalBytes += Math.Max(0, gamePart.SizeBytes);
        }

        if (File.Exists(destinationPath))
        {
            File.Delete(destinationPath);
        }

        await using var destination = File.Create(destinationPath);
        long downloadedBytes = 0;
        long assembledBytes = 0;
        for (var index = 0; index < manifest.GameParts.Count; index++)
        {
            var part = manifest.GameParts[index];
            if (string.IsNullOrWhiteSpace(part.Url))
            {
                return BuildDownloadInvalidResult(
                    $"Le manifest GitHub ne reference pas correctement la partie {index + 1}.",
                    "LAUNCH-INSTALL-008"
                );
            }

            ReportStatus(progress, $"Telechargement du jeu ({index + 1}/{manifest.GameParts.Count})...", 5);
            using var response = await HttpClient.GetAsync(
                part.Url,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken
            );
            if (!response.IsSuccessStatusCode)
            {
                return BuildDownloadHttpErrorResult((int)response.StatusCode, index + 1, manifest.GameParts.Count);
            }

            var partPath = Path.Combine(partDirectory, $"game.part{index + 1:D2}.download");
            if (File.Exists(partPath))
            {
                File.Delete(partPath);
            }

            await using (var source = await response.Content.ReadAsStreamAsync(cancellationToken))
            await using (var partDestination = File.Create(partPath))
            {
                var partBytes = part.SizeBytes > 0 ? part.SizeBytes : (response.Content.Headers.ContentLength ?? 0);
                await CopyStreamWithProgressAsync(
                    source,
                    partDestination,
                    partBytes,
                    copiedBytes => ReportWeightedProgress(
                        progress,
                        $"Telechargement du jeu ({index + 1}/{manifest.GameParts.Count})...",
                        downloadedBytes + copiedBytes,
                        totalBytes,
                        5,
                        88
                    ),
                    cancellationToken
                );
            }

            var partInfo = new FileInfo(partPath);
            if (!partInfo.Exists || (part.SizeBytes > 0 && partInfo.Length != part.SizeBytes))
            {
                File.Delete(partPath);
                return BuildDownloadInvalidResult(
                    $"La partie {index + 1}/{manifest.GameParts.Count} est incomplete ou invalide."
                );
            }

            if (!string.IsNullOrWhiteSpace(part.Sha256))
            {
                var partHash = await ComputeSha256Async(partPath, cancellationToken);
                if (!string.Equals(partHash, part.Sha256.Trim(), StringComparison.OrdinalIgnoreCase))
                {
                    File.Delete(partPath);
                    return BuildDownloadInvalidResult(
                        $"La partie {index + 1}/{manifest.GameParts.Count} ne correspond pas au hash attendu.",
                        "LAUNCH-INSTALL-009"
                    );
                }
            }

            await using (var partSource = File.OpenRead(partPath))
            {
                await CopyStreamWithProgressAsync(
                    partSource,
                    destination,
                    partInfo.Length,
                    copiedBytes => ReportWeightedProgress(
                        progress,
                        $"Assemblage du build ({index + 1}/{manifest.GameParts.Count})...",
                        assembledBytes + copiedBytes,
                        totalBytes,
                        88,
                        96
                    ),
                    cancellationToken
                );
            }

            downloadedBytes += partInfo.Length;
            assembledBytes += partInfo.Length;
            File.Delete(partPath);
        }

        if (Directory.Exists(partDirectory))
        {
            Directory.Delete(partDirectory, true);
        }

        return new EnsureInstallResult { Success = true };
    }

    private async Task<EnsureInstallResult> TryInstallFromBundle(IProgress<LauncherProgressReport>? progress, bool repairMode)
    {
        var bundledGamePath = TryResolveBundledGamePath();
        if (bundledGamePath is null)
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
            ReportStatus(progress, repairMode ? "Reparation depuis le bundle local..." : "Installation depuis le bundle local...", 8);
            Directory.CreateDirectory(_installRoot);
            await using (var source = File.OpenRead(bundledGamePath))
            await using (var destination = File.Create(InstalledGamePath))
            {
                var sourceLength = source.Length;
                await CopyStreamWithProgressAsync(
                    source,
                    destination,
                    sourceLength,
                    copiedBytes => ReportWeightedProgress(
                        progress,
                        repairMode ? "Reparation du build local..." : "Installation du build local...",
                        copiedBytes,
                        sourceLength,
                        8,
                        96
                    ),
                    CancellationToken.None
                );
            }

            var version = NormalizeVersion(Application.ProductVersion ?? "1.2.0");
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
            // The currently running launcher remains usable even if the shadow copy fails.
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
        client.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("VoxelRTXLauncher", "1.2.0"));
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

        return false;
    }

    private static List<int> ExtractVersionParts(string version)
    {
        var parts = new List<int>();
        foreach (var rawPart in version.Split('.', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            parts.Add(int.TryParse(rawPart, out var value) ? value : 0);
        }

        if (parts.Count == 0)
        {
            parts.Add(0);
        }

        return parts;
    }
}
