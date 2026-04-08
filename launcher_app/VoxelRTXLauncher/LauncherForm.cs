using System.Diagnostics;

namespace VoxelRTXLauncher;

internal sealed class LauncherForm : Form
{
    private static readonly Color WindowBack = Color.FromArgb(14, 20, 30);
    private static readonly Color PanelBack = Color.FromArgb(24, 34, 48);
    private static readonly Color Accent = Color.FromArgb(89, 195, 255);
    private static readonly Color TextPrimary = Color.FromArgb(240, 246, 255);
    private static readonly Color TextMuted = Color.FromArgb(170, 184, 205);
    private static readonly Color ErrorColor = Color.FromArgb(255, 118, 118);

    private readonly LauncherContract _contract;
    private readonly LauncherService _launcherService;

    private Label _statusLabel = null!;
    private Button _playButton = null!;
    private ProgressBar _progressBar = null!;
    private bool _autoLaunchRequested;
    private bool _busy;

    public LauncherForm()
    {
        _contract = LauncherContract.Load(AppContext.BaseDirectory);
        _launcherService = new LauncherService(_contract);

        BuildUi();
        RefreshState();
        TryAutoLaunchFromCommandLine();
    }

    private void BuildUi()
    {
        SuspendLayout();

        Text = "Voxel RTX Launcher";
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        MinimizeBox = false;
        ClientSize = new Size(480, 286);
        BackColor = WindowBack;
        Font = new Font("Segoe UI", 10.5F, FontStyle.Regular, GraphicsUnit.Point);

        var card = new Panel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(24),
            Margin = new Padding(18),
            BackColor = PanelBack,
        };
        Controls.Add(card);

        var titleLabel = new Label
        {
            Dock = DockStyle.Top,
            Height = 42,
            Text = "Voxel RTX",
            TextAlign = ContentAlignment.MiddleCenter,
            Font = new Font("Segoe UI Semibold", 24F, FontStyle.Bold),
            ForeColor = TextPrimary,
        };
        card.Controls.Add(titleLabel);

        var subtitleLabel = new Label
        {
            Dock = DockStyle.Top,
            Height = 58,
            Text = "Installe le jeu si besoin, verifie GitHub, repare l'installation, puis lance le build securise.",
            TextAlign = ContentAlignment.MiddleCenter,
            ForeColor = TextMuted,
        };
        card.Controls.Add(subtitleLabel);

        _playButton = new Button
        {
            Text = "Jouer",
            Width = 220,
            Height = 52,
            FlatStyle = FlatStyle.Flat,
            BackColor = Accent,
            ForeColor = Color.FromArgb(10, 20, 28),
            Font = new Font("Segoe UI Semibold", 16F, FontStyle.Bold),
        };
        _playButton.FlatAppearance.BorderSize = 0;
        _playButton.Click += PlayButton_Click;

        var buttonHost = new Panel
        {
            Dock = DockStyle.Fill,
            BackColor = Color.Transparent,
        };
        buttonHost.Resize += (_, _) =>
        {
            _playButton.Left = (buttonHost.ClientSize.Width - _playButton.Width) / 2;
            _playButton.Top = Math.Max(12, (buttonHost.ClientSize.Height - _playButton.Height) / 2);
        };
        buttonHost.Controls.Add(_playButton);
        card.Controls.Add(buttonHost);

        _progressBar = new ProgressBar
        {
            Dock = DockStyle.Bottom,
            Height = 12,
            Visible = false,
            Style = ProgressBarStyle.Marquee,
            MarqueeAnimationSpeed = 28,
        };
        card.Controls.Add(_progressBar);

        _statusLabel = new Label
        {
            Dock = DockStyle.Bottom,
            Height = 58,
            TextAlign = ContentAlignment.MiddleCenter,
            ForeColor = TextMuted,
            Text = "Pret.",
        };
        card.Controls.Add(_statusLabel);

        ResumeLayout(true);
    }

    private void RefreshState()
    {
        if (_launcherService.HasInstalledGame)
        {
            SetStatus("Installation detectee. Le launcher verifiera GitHub avant le lancement.", false);
            _playButton.Enabled = true;
            return;
        }

        if (_launcherService.HasBundledGame)
        {
            SetStatus("Jeu non installe. Clique sur Jouer pour installer le build local dans AppData.", false);
            _playButton.Enabled = true;
            return;
        }

        SetStatus("Jeu non detecte localement. Clique sur Jouer pour tenter une installation via GitHub.", false);
        _playButton.Enabled = true;
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
        _progressBar.Visible = true;

        try
        {
            var progress = new Progress<string>(message => SetStatus(message, false));
            var result = await _launcherService.EnsureGameReadyAsync(progress);
            if (!result.Success)
            {
                ShowError(
                    string.IsNullOrWhiteSpace(result.ErrorCode) ? "LAUNCH-GAME-500" : result.ErrorCode,
                    result.Status
                );
                return;
            }

            SetStatus(result.Status, false);
            LaunchInstalledGame(result.GamePath);
        }
        finally
        {
            FinishBusyState();
        }
    }

    private void LaunchInstalledGame(string gamePath)
    {
        if (!File.Exists(gamePath))
        {
            ShowError("LAUNCH-GAME-404", $"Jeu introuvable: {gamePath}");
            return;
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
                ShowError("LAUNCH-GAME-500", "Le processus du jeu n'a pas pu demarrer.");
                return;
            }

            Close();
        }
        catch (Exception ex)
        {
            ShowError("LAUNCH-GAME-500", ex.Message);
        }
    }

    private void SetStatus(string message, bool isError)
    {
        _statusLabel.Text = message;
        _statusLabel.ForeColor = isError ? ErrorColor : TextMuted;
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

        _progressBar.Visible = false;
        _playButton.Enabled = true;
    }
}
