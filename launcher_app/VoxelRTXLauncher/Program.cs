using System.Diagnostics;

namespace VoxelRTXLauncher;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        LauncherInstanceGuard.ClosePreviousLaunchers();
        ApplicationConfiguration.Initialize();
        Application.Run(new LauncherForm());
    }
}

internal static class LauncherInstanceGuard
{
    public static void ClosePreviousLaunchers()
    {
        using var currentProcess = Process.GetCurrentProcess();
        Process[] runningInstances;
        try
        {
            runningInstances = Process.GetProcessesByName(currentProcess.ProcessName);
        }
        catch
        {
            return;
        }

        foreach (var process in runningInstances)
        {
            if (process.Id == currentProcess.Id)
            {
                continue;
            }

            try
            {
                if (!process.HasExited)
                {
                    process.CloseMainWindow();
                    if (!process.WaitForExit(1200))
                    {
                        process.Kill(true);
                        process.WaitForExit(4000);
                    }
                }
            }
            catch
            {
            }
            finally
            {
                process.Dispose();
            }
        }
    }
}
