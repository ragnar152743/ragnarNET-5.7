namespace VoxelRTXLauncher;

internal readonly record struct LauncherProgressReport(string Message, double? Percent = null)
{
    public static LauncherProgressReport Status(string message)
    {
        return new LauncherProgressReport(message, null);
    }

    public static LauncherProgressReport Progress(string message, double percent)
    {
        return new LauncherProgressReport(message, Math.Clamp(percent, 0d, 100d));
    }
}
