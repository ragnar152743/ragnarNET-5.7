namespace VoxelRTXLauncher;

internal sealed class EnsureInstallResult
{
    public bool Success { get; init; }
    public string ErrorCode { get; init; } = "";
    public string Status { get; init; } = "";
    public string GamePath { get; init; } = "";
    public string InstalledVersion { get; init; } = "";
    public bool InstalledFromBundle { get; init; }
    public bool InstalledFromGitHub { get; init; }
    public bool UpdatedFromGitHub { get; init; }
    public bool RepairedInstall { get; init; }
    public string LauncherStatus { get; init; } = "";
}
