using System.Diagnostics;
using System.Runtime.InteropServices;

namespace VoxelRTXLauncher;

internal sealed class LauncherForm : Form
{
    private static readonly Color WindowBack = Color.FromArgb(7, 12, 20);
    private static readonly Color ShellBack = Color.FromArgb(14, 20, 31);
    private static readonly Color CardBack = Color.FromArgb(19, 28, 43);
    private static readonly Color Accent = Color.FromArgb(89, 195, 255);
    private static readonly Color TextPrimary = Color.FromArgb(241, 246, 255);
    private static readonly Color TextMuted = Color.FromArgb(164, 181, 208);
    private static readonly Color ErrorColor = Color.FromArgb(255, 128, 128);
    private const int StableLaunchProbeCount = 18;
    private const int StableLaunchProbeDelayMs = 250;
    private const int WmNclButtonDown = 0xA1;
    private const int HtCaption = 0x2;

    private readonly LauncherContract _contract;
    private readonly LauncherService _launcherService;

    private Label _statusTitleLabel = null!;
    private Label _statusLabel = null!;
    private Label _installationLabel = null!;
    private Label _footerLabel = null!;
    private Label _progressLabel = null!;
    private LauncherBadge _stateBadge = null!;
    private LauncherBadge _installBadge = null!;
    private LauncherBadge _repoBadge = null!;
    private LauncherAccentButton _playButton = null!;
    private LauncherActivityBar _activityBar = null!;
    private bool _autoLaunchRequested;
    private bool _busy;
    private string _defaultStatusTitle = "Pret au lancement";

    public LauncherForm()
    {
        _contract = LauncherContract.Load(AppContext.BaseDirectory);
        _launcherService = new LauncherService(_contract);

        BuildUi();
        RefreshState();
        TryAutoLaunchFromCommandLine();
    }

    [DllImport("user32.dll")]
    private static extern bool ReleaseCapture();

    [DllImport("user32.dll")]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, int wParam, int lParam);

    private void BuildUi()
    {
        SuspendLayout();

        Text = "Voxel RTX Launcher";
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.None;
        MaximizeBox = false;
        MinimizeBox = true;
        ClientSize = new Size(1024, 648);
        MinimumSize = new Size(940, 584);
        BackColor = WindowBack;
        Font = new Font("Segoe UI", 10.2f, FontStyle.Regular, GraphicsUnit.Point);
        Padding = new Padding(14);
        SetStyle(
            ControlStyles.AllPaintingInWmPaint
                | ControlStyles.OptimizedDoubleBuffer
                | ControlStyles.ResizeRedraw
                | ControlStyles.UserPaint,
            true
        );

        var shell = new LauncherChromePanel
        {
            Dock = DockStyle.Fill,
            FillColor = ShellBack,
            BorderColor = Color.FromArgb(44, 61, 88),
            CornerRadius = 30,
            Padding = new Padding(1),
        };
        Controls.Add(shell);

        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 2,
            BackColor = Color.Transparent,
            Margin = Padding.Empty,
            Padding = Padding.Empty,
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 64f));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
        shell.Controls.Add(root);

        var topBar = new Panel
        {
            Dock = DockStyle.Fill,
            BackColor = Color.Transparent,
            Padding = new Padding(24, 16, 18, 8),
            Margin = Padding.Empty,
        };
        root.Controls.Add(topBar, 0, 0);
        AttachWindowDrag(topBar);

        var brandLabel = new Label
        {
            Dock = DockStyle.Left,
            Width = 360,
            Text = "VOXEL RTX LAUNCHER",
            Font = new Font("Segoe UI Semibold", 11.5f, FontStyle.Bold, GraphicsUnit.Point),
            ForeColor = TextPrimary,
            TextAlign = ContentAlignment.MiddleLeft,
        };
        topBar.Controls.Add(brandLabel);
        AttachWindowDrag(brandLabel);

        var versionLabel = new Label
        {
            Dock = DockStyle.Left,
            Width = 120,
            Text = $"v{Application.ProductVersion}",
            Font = new Font("Segoe UI", 9.8f, FontStyle.Regular, GraphicsUnit.Point),
            ForeColor = TextMuted,
            TextAlign = ContentAlignment.MiddleLeft,
        };
        topBar.Controls.Add(versionLabel);
        AttachWindowDrag(versionLabel);

        var windowButtons = new FlowLayoutPanel
        {
            Dock = DockStyle.Right,
            Width = 108,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = false,
            BackColor = Color.Transparent,
            Margin = Padding.Empty,
            Padding = Padding.Empty,
        };
        topBar.Controls.Add(windowButtons);

        var minimizeButton = new LauncherGhostButton
        {
            Text = "-",
            Margin = new Padding(0, 0, 8, 0),
        };
        minimizeButton.Click += (_, _) => WindowState = FormWindowState.Minimized;
        windowButtons.Controls.Add(minimizeButton);

        var closeButton = new LauncherGhostButton
        {
            Text = "X",
            ForeColor = Color.FromArgb(255, 232, 232),
            Margin = Padding.Empty,
        };
        closeButton.Click += (_, _) => Close();
        windowButtons.Controls.Add(closeButton);

        var content = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            BackColor = Color.Transparent,
            Padding = new Padding(24, 12, 24, 24),
            Margin = Padding.Empty,
        };
        content.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 56f));
        content.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 44f));
        root.Controls.Add(content, 0, 1);

        var heroPanel = new LauncherHeroPanel
        {
            Dock = DockStyle.Fill,
            Margin = new Padding(0, 0, 12, 0),
            Padding = new Padding(32, 30, 32, 30),
            CornerRadius = 28,
            BorderColor = Color.FromArgb(72, 98, 132),
        };
        content.Controls.Add(heroPanel, 0, 0);
        AttachWindowDrag(heroPanel);

        var heroStack = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            BackColor = Color.Transparent,
            Margin = Padding.Empty,
            Padding = Padding.Empty,
        };
        heroPanel.Controls.Add(heroStack);
        AttachWindowDrag(heroStack);

        var heroEyebrow = new LauncherBadge
        {
            Text = "SECURE RUNTIME FEED",
            FillColor = Color.FromArgb(28, 56, 88),
            BorderColor = Color.FromArgb(84, 129, 186),
            BadgeTextColor = TextPrimary,
            Margin = new Padding(0, 0, 0, 18),
            Size = new Size(196, 34),
        };
        heroStack.Controls.Add(heroEyebrow);

        var heroTitle = new Label
        {
            AutoSize = false,
            Size = new Size(456, 122),
            Text = "Runtime propre.\r\nPatch propre.",
            Font = new Font("Segoe UI Semibold", 28f, FontStyle.Bold, GraphicsUnit.Point),
            ForeColor = TextPrimary,
            TextAlign = ContentAlignment.MiddleLeft,
            Margin = new Padding(0, 0, 0, 16),
        };
        heroStack.Controls.Add(heroTitle);
        AttachWindowDrag(heroTitle);

        var heroBody = new Label
        {
            AutoSize = false,
            Size = new Size(468, 88),
            Text = "Le launcher gere l'installation locale, la reparation, le feed GitHub multi-parties et le demarrage securise sans laisser de flux brouillon cote jeu.",
            Font = new Font("Segoe UI", 11.2f, FontStyle.Regular, GraphicsUnit.Point),
            ForeColor = Color.FromArgb(221, 234, 249),
            TextAlign = ContentAlignment.TopLeft,
            Margin = new Padding(0, 0, 0, 18),
        };
        heroStack.Controls.Add(heroBody);
        AttachWindowDrag(heroBody);

        var heroBadges = new FlowLayoutPanel
        {
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = true,
            BackColor = Color.Transparent,
            Margin = new Padding(0, 0, 0, 22),
            Padding = Padding.Empty,
        };
        heroStack.Controls.Add(heroBadges);
        heroBadges.Controls.Add(
            new LauncherBadge
            {
                Text = "1 INSTANCE ACTIVE",
                FillColor = Color.FromArgb(23, 48, 73),
                BorderColor = Color.FromArgb(68, 122, 188),
                BadgeTextColor = TextPrimary,
                Margin = new Padding(0, 0, 10, 10),
                Size = new Size(164, 34),
            }
        );
        heroBadges.Controls.Add(
            new LauncherBadge
            {
                Text = "REPAIR AUTO",
                FillColor = Color.FromArgb(22, 54, 72),
                BorderColor = Color.FromArgb(77, 154, 198),
                BadgeTextColor = TextPrimary,
                Margin = new Padding(0, 0, 10, 10),
                Size = new Size(132, 34),
            }
        );
        heroBadges.Controls.Add(
            new LauncherBadge
            {
                Text = "RUNTIME FEED",
                FillColor = Color.FromArgb(24, 45, 63),
                BorderColor = Color.FromArgb(85, 118, 162),
                BadgeTextColor = TextPrimary,
                Margin = new Padding(0, 0, 0, 10),
                Size = new Size(136, 34),
            }
        );

        var heroMetrics = new TableLayoutPanel
        {
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            ColumnCount = 1,
            RowCount = 3,
            BackColor = Color.FromArgb(34, 56, 82),
            Padding = new Padding(18, 16, 18, 16),
            Margin = Padding.Empty,
        };
        heroMetrics.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        heroMetrics.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        heroMetrics.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        heroStack.Controls.Add(heroMetrics);
        heroMetrics.Controls.Add(CreateMetricLabel("Install target", "%LocalAppData%\\Programs\\VoxelRTX"), 0, 0);
        heroMetrics.Controls.Add(CreateMetricLabel("Remote feed", "distribution/game + launcher + manifests"), 0, 1);
        heroMetrics.Controls.Add(CreateMetricLabel("Launch contract", "Secure key + nonce + token"), 0, 2);

        var statusPanel = new LauncherChromePanel
        {
            Dock = DockStyle.Fill,
            Margin = new Padding(12, 0, 0, 0),
            Padding = new Padding(28),
            FillColor = CardBack,
            BorderColor = Color.FromArgb(57, 76, 104),
            CornerRadius = 28,
        };
        content.Controls.Add(statusPanel, 1, 0);

        var statusStack = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 8,
            BackColor = Color.Transparent,
            Margin = Padding.Empty,
            Padding = Padding.Empty,
        };
        statusStack.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        statusStack.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        statusStack.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        statusStack.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        statusStack.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));
        statusStack.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        statusStack.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        statusStack.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        statusPanel.Controls.Add(statusStack);

        var sectionLabel = new Label
        {
            AutoSize = true,
            Text = "LAUNCH CONTROL",
            Font = new Font("Segoe UI Semibold", 10f, FontStyle.Bold, GraphicsUnit.Point),
            ForeColor = Accent,
            Margin = new Padding(0, 0, 0, 10),
        };
        statusStack.Controls.Add(sectionLabel, 0, 0);

        _statusTitleLabel = new Label
        {
            AutoSize = false,
            Height = 44,
            Dock = DockStyle.Top,
            Text = _defaultStatusTitle,
            Font = new Font("Segoe UI Semibold", 22f, FontStyle.Bold, GraphicsUnit.Point),
            ForeColor = TextPrimary,
            TextAlign = ContentAlignment.MiddleLeft,
            Margin = new Padding(0, 0, 0, 8),
        };
        statusStack.Controls.Add(_statusTitleLabel, 0, 1);

        _statusLabel = new Label
        {
            AutoSize = false,
            Height = 92,
            Dock = DockStyle.Top,
            Text = "Pret.",
            Font = new Font("Segoe UI", 10.8f, FontStyle.Regular, GraphicsUnit.Point),
            ForeColor = TextMuted,
            TextAlign = ContentAlignment.TopLeft,
            Margin = new Padding(0, 0, 0, 14),
        };
        statusStack.Controls.Add(_statusLabel, 0, 2);

        var badgeRow = new FlowLayoutPanel
        {
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = true,
            BackColor = Color.Transparent,
            Margin = new Padding(0, 0, 0, 14),
            Padding = Padding.Empty,
        };
        statusStack.Controls.Add(badgeRow, 0, 3);

        _stateBadge = new LauncherBadge
        {
            Text = "READY",
            FillColor = Color.FromArgb(23, 49, 72),
            BorderColor = Color.FromArgb(82, 135, 194),
            BadgeTextColor = TextPrimary,
            Size = new Size(110, 34),
            Margin = new Padding(0, 0, 10, 10),
        };
        badgeRow.Controls.Add(_stateBadge);

        _installBadge = new LauncherBadge
        {
            Text = "APPDATA",
            FillColor = Color.FromArgb(25, 44, 64),
            BorderColor = Color.FromArgb(69, 107, 150),
            BadgeTextColor = TextPrimary,
            Size = new Size(118, 34),
            Margin = new Padding(0, 0, 10, 10),
        };
        badgeRow.Controls.Add(_installBadge);

        _repoBadge = new LauncherBadge
        {
            Text = "GITHUB",
            FillColor = Color.FromArgb(28, 40, 58),
            BorderColor = Color.FromArgb(79, 98, 126),
            BadgeTextColor = TextPrimary,
            Size = new Size(112, 34),
            Margin = new Padding(0, 0, 0, 10),
        };
        badgeRow.Controls.Add(_repoBadge);

        _installationLabel = new Label
        {
            AutoSize = false,
            Height = 72,
            Dock = DockStyle.Top,
            Text = "",
            Font = new Font("Segoe UI", 10f, FontStyle.Regular, GraphicsUnit.Point),
            ForeColor = Color.FromArgb(196, 210, 230),
            TextAlign = ContentAlignment.TopLeft,
            Margin = new Padding(0, 0, 0, 18),
        };
        statusStack.Controls.Add(_installationLabel, 0, 4);

        _footerLabel = new Label
        {
            AutoSize = false,
            Height = 52,
            Dock = DockStyle.Top,
            Text = "Le launcher coupe les anciennes instances avant d'ouvrir la nouvelle fenetre.",
            Font = new Font("Segoe UI", 9.8f, FontStyle.Regular, GraphicsUnit.Point),
            ForeColor = TextMuted,
            TextAlign = ContentAlignment.BottomLeft,
            Margin = new Padding(0, 0, 0, 18),
        };
        statusStack.Controls.Add(_footerLabel, 0, 5);

        _activityBar = new LauncherActivityBar
        {
            Dock = DockStyle.Top,
            Height = 14,
            Margin = new Padding(0, 0, 0, 8),
        };
        statusStack.Controls.Add(_activityBar, 0, 6);

        _progressLabel = new Label
        {
            AutoSize = false,
            Height = 22,
            Dock = DockStyle.Top,
            Text = "Standby",
            Font = new Font("Segoe UI Semibold", 9.8f, FontStyle.Bold, GraphicsUnit.Point),
            ForeColor = Color.FromArgb(205, 231, 255),
            TextAlign = ContentAlignment.MiddleRight,
            Margin = new Padding(0, 0, 0, 16),
        };
        statusStack.Controls.Add(_progressLabel, 0, 7);

        var buttonHost = new Panel
        {
            Dock = DockStyle.Top,
            Height = 72,
            BackColor = Color.Transparent,
            Margin = Padding.Empty,
        };
        statusStack.Controls.Add(buttonHost, 0, 8);

        _playButton = new LauncherAccentButton
        {
            Text = "Jouer",
            Anchor = AnchorStyles.None,
        };
        _playButton.Click += PlayButton_Click;
        buttonHost.Controls.Add(_playButton);
        buttonHost.Resize += (_, _) =>
        {
            _playButton.Left = Math.Max(0, (buttonHost.ClientSize.Width - _playButton.Width) / 2);
            _playButton.Top = Math.Max(0, (buttonHost.ClientSize.Height - _playButton.Height) / 2);
        };

        Resize += (_, _) => UpdateWindowRegion();
        Shown += (_, _) => UpdateWindowRegion();
        ResumeLayout(true);
    }

    private async void PlayButton_Click(object? sender, EventArgs e)
    {
        await RunPlayFlowAsync();
    }

    private async Task RunPlayFlowAsync()
    {
        if (_busy)
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(_contract.LaunchKey))
        {
            ShowError("LAUNCH-KEY-500", "La cle du launcher est absente du contrat.");
            return;
        }

        _busy = true;
        _playButton.Enabled = false;
        _playButton.Text = "Preparation...";
        _activityBar.Active = true;
        _statusTitleLabel.Text = "Verification en cours";

        try
        {
            IProgress<LauncherProgressReport> progress = new Progress<LauncherProgressReport>(ApplyProgress);
            var result = await _launcherService.EnsureGameReadyAsync(progress);
            if (!result.Success)
            {
                ShowError(
                    string.IsNullOrWhiteSpace(result.ErrorCode) ? "LAUNCH-GAME-500" : result.ErrorCode,
                    result.Status
                );
                return;
            }

            SetStatus(CombineStatus(result.Status, result.LauncherStatus), false);
            var launchAttempt = await TryLaunchInstalledGameAsync(result.GamePath, progress);
            if (launchAttempt.Success)
            {
                Close();
                return;
            }

            progress.Report(LauncherProgressReport.Status("Le jeu est retombe trop vite, reparation forcee..."));
            var repairResult = await _launcherService.EnsureGameReadyAsync(progress, forceRepair: true);
            if (!repairResult.Success)
            {
                ShowError(
                    string.IsNullOrWhiteSpace(repairResult.ErrorCode) ? "LAUNCH-REPAIR-500" : repairResult.ErrorCode,
                    repairResult.Status
                );
                return;
            }

            SetStatus(CombineStatus(repairResult.Status, repairResult.LauncherStatus), false);
            var repairLaunchAttempt = await TryLaunchInstalledGameAsync(repairResult.GamePath, progress);
            if (!repairLaunchAttempt.Success)
            {
                ShowError(repairLaunchAttempt.ErrorCode, repairLaunchAttempt.Detail);
                return;
            }

            Close();
        }
        finally
        {
            FinishBusyState();
        }
    }

    private async Task<(bool Success, string ErrorCode, string Detail)> TryLaunchInstalledGameAsync(
        string gamePath,
        IProgress<LauncherProgressReport>? progress
    )
    {
        if (!File.Exists(gamePath))
        {
            return (false, "LAUNCH-GAME-404", $"Jeu introuvable: {gamePath}");
        }

        var nonce = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString();
        var token = _contract.BuildToken(_contract.LaunchKey, nonce);

        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = gamePath,
                UseShellExecute = false,
                WorkingDirectory = Path.GetDirectoryName(gamePath) ?? AppContext.BaseDirectory,
            };
            startInfo.ArgumentList.Add($"--launcher-key={_contract.LaunchKey}");
            startInfo.ArgumentList.Add($"--launcher-nonce={nonce}");
            startInfo.ArgumentList.Add($"--launcher-token={token}");
            startInfo.EnvironmentVariables["VOXELRTX_LAUNCHER_KEY"] = _contract.LaunchKey;
            startInfo.EnvironmentVariables["VOXELRTX_LAUNCHER_NONCE"] = nonce;
            startInfo.EnvironmentVariables["VOXELRTX_LAUNCHER_TOKEN"] = token;

            var process = Process.Start(startInfo);
            if (process is null)
            {
                return (false, "LAUNCH-GAME-500", "Le processus du jeu n'a pas pu demarrer.");
            }

            progress?.Report(LauncherProgressReport.Progress("Verification du demarrage reel du jeu...", 100));
            for (var probe = 0; probe < StableLaunchProbeCount; probe++)
            {
                await Task.Delay(StableLaunchProbeDelayMs);
                if (!process.HasExited)
                {
                    continue;
                }

                return (
                    false,
                    "LAUNCH-GAME-FASTEXIT",
                    "Le jeu s'est ferme juste apres le lancement. Reinstallation demandee."
                );
            }

            return (true, "", "");
        }
        catch (Exception ex)
        {
            return (false, "LAUNCH-GAME-500", ex.Message);
        }
    }

    private void RefreshState()
    {
        if (_launcherService.HasInstalledGame)
        {
            _defaultStatusTitle = "Jeu pret";
            _stateBadge.Text = "READY";
            _installBadge.Text = "APPDATA";
            _repoBadge.Text = "GITHUB";
            _installationLabel.Text = "Installation detectee dans AppData. Le launcher va verifier les manifests puis envoyer la cle securisee au jeu au moment du demarrage.";
            _footerLabel.Text = "Une seule fenetre launcher reste autorisee. Toute ancienne instance est fermee avant affichage.";
            SetStatus("Installation detectee. Verification des manifests et lancement securise a l'appui.", false);
            _progressLabel.Text = "Local ready";
            _activityBar.ProgressPercent = null;
            _playButton.Enabled = true;
            return;
        }

        if (_launcherService.HasBundledGame)
        {
            _defaultStatusTitle = "Installation requise";
            _stateBadge.Text = "INSTALL";
            _installBadge.Text = "BUNDLE";
            _repoBadge.Text = "GITHUB";
            _installationLabel.Text = "Jeu non installe. Le launcher peut copier le build embarque dans AppData ou reparer l'installation si elle est endommagee.";
            _footerLabel.Text = "Le launcher priorise la stabilite: verifier, installer, reparer, puis seulement lancer.";
            SetStatus("Jeu non installe. Clique sur Jouer pour installer le build local dans AppData.", false);
            _progressLabel.Text = "Bundle detecte";
            _activityBar.ProgressPercent = null;
            _playButton.Enabled = true;
            return;
        }

        _defaultStatusTitle = "Sync distante";
        _stateBadge.Text = "REMOTE";
        _installBadge.Text = "APPDATA";
        _repoBadge.Text = "GITHUB";
        _installationLabel.Text = "Aucun build local detecte. Le launcher va s'appuyer sur GitHub pour tenter une installation propre avant lancement.";
        _footerLabel.Text = "Si le jeu tombe au demarrage, le launcher force une reinstallation puis relance une seconde tentative.";
        SetStatus("Jeu non detecte localement. Clique sur Jouer pour tenter une installation via GitHub.", false);
        _progressLabel.Text = "Remote sync";
        _activityBar.ProgressPercent = null;
        _playButton.Enabled = true;
    }

    private void SetStatus(string message, bool isError)
    {
        _statusTitleLabel.Text = isError ? "Erreur de lancement" : (_busy ? "Verification en cours" : _defaultStatusTitle);
        _statusLabel.Text = message;
        _statusLabel.ForeColor = isError ? ErrorColor : TextMuted;
    }

    private void ApplyProgress(LauncherProgressReport progress)
    {
        SetStatus(progress.Message, false);
        if (progress.Percent.HasValue)
        {
            var percent = Math.Clamp(progress.Percent.Value, 0d, 100d);
            _activityBar.ProgressPercent = percent;
            _progressLabel.Text = $"{percent:0.0}%";
        }
        else
        {
            _activityBar.ProgressPercent = null;
            _progressLabel.Text = "Syncing";
        }
    }

    private void ShowError(string code, string detail)
    {
        SetStatus($"{code} | {detail}", true);
        MessageBox.Show(
            this,
            $"{detail}{Environment.NewLine}{Environment.NewLine}Code erreur: {code}",
            "Voxel RTX Launcher",
            MessageBoxButtons.OK,
            MessageBoxIcon.Error
        );
    }

    private void TryAutoLaunchFromCommandLine()
    {
        foreach (var argument in Environment.GetCommandLineArgs())
        {
            if (string.Equals(argument, "--autoplay", StringComparison.OrdinalIgnoreCase))
            {
                _autoLaunchRequested = true;
                return;
            }
        }
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);

        if (_autoLaunchRequested)
        {
            _autoLaunchRequested = false;
            BeginInvoke(async () => await RunPlayFlowAsync());
        }
    }

    private void FinishBusyState()
    {
        _busy = false;
        if (IsDisposed)
        {
            return;
        }

        _activityBar.Active = false;
        _activityBar.ProgressPercent = null;
        _playButton.Enabled = true;
        _playButton.Text = "Jouer";
        if (_statusLabel.ForeColor != ErrorColor)
        {
            _statusTitleLabel.Text = _defaultStatusTitle;
        }
    }

    private void AttachWindowDrag(Control control)
    {
        control.MouseDown += (_, e) =>
        {
            if (e.Button != MouseButtons.Left)
            {
                return;
            }

            ReleaseCapture();
            SendMessage(Handle, WmNclButtonDown, HtCaption, 0);
        };
    }

    private void UpdateWindowRegion()
    {
        if (Width <= 0 || Height <= 0)
        {
            return;
        }

        using var path = LauncherDrawing.CreateRoundedPath(new Rectangle(0, 0, Width, Height), 34);
        Region = new Region(path);
    }

    private static Control CreateMetricLabel(string title, string value)
    {
        return new Label
        {
            AutoSize = false,
            Size = new Size(454, 42),
            Text = $"{title}: {value}",
            Font = new Font("Segoe UI", 10f, FontStyle.Regular, GraphicsUnit.Point),
            ForeColor = Color.FromArgb(228, 238, 252),
            TextAlign = ContentAlignment.MiddleLeft,
            Margin = new Padding(0, 0, 0, 8),
        };
    }

    private static string CombineStatus(string primary, string secondary)
    {
        if (string.IsNullOrWhiteSpace(secondary))
        {
            return primary;
        }

        return $"{primary} {secondary}";
    }
}
