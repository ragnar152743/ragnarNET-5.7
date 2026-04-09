using System.ComponentModel;
using System.Drawing.Drawing2D;

namespace VoxelRTXLauncher;

internal static class LauncherDrawing
{
    public static GraphicsPath CreateRoundedPath(Rectangle bounds, int radius)
    {
        var safeRadius = Math.Max(4, Math.Min(radius, Math.Min(bounds.Width, bounds.Height) / 2));
        var diameter = safeRadius * 2;
        var path = new GraphicsPath();

        path.StartFigure();
        path.AddArc(bounds.X, bounds.Y, diameter, diameter, 180, 90);
        path.AddArc(bounds.Right - diameter, bounds.Y, diameter, diameter, 270, 90);
        path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(bounds.X, bounds.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }
}

internal class LauncherChromePanel : Panel
{
    [Browsable(false)]
    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public Color FillColor { get; set; } = Color.FromArgb(22, 28, 41);
    [Browsable(false)]
    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public Color BorderColor { get; set; } = Color.FromArgb(55, 71, 97);
    [Browsable(false)]
    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public int CornerRadius { get; set; } = 28;

    public LauncherChromePanel()
    {
        DoubleBuffered = true;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        e.Graphics.Clear(Parent?.BackColor ?? Color.Black);

        var bounds = ClientRectangle;
        if (bounds.Width <= 1 || bounds.Height <= 1)
        {
            return;
        }

        bounds.Width -= 1;
        bounds.Height -= 1;

        using var path = LauncherDrawing.CreateRoundedPath(bounds, CornerRadius);
        using var fill = new SolidBrush(FillColor);
        using var border = new Pen(BorderColor, 1.2f);
        e.Graphics.FillPath(fill, path);
        e.Graphics.DrawPath(border, path);
    }
}

internal sealed class LauncherHeroPanel : LauncherChromePanel
{
    [Browsable(false)]
    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public Color AccentColorA { get; set; } = Color.FromArgb(61, 136, 255);
    [Browsable(false)]
    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public Color AccentColorB { get; set; } = Color.FromArgb(68, 222, 196);

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        e.Graphics.Clear(Parent?.BackColor ?? Color.Black);

        var bounds = ClientRectangle;
        if (bounds.Width <= 1 || bounds.Height <= 1)
        {
            return;
        }

        bounds.Width -= 1;
        bounds.Height -= 1;

        using var path = LauncherDrawing.CreateRoundedPath(bounds, CornerRadius);
        using var gradient = new LinearGradientBrush(
            bounds,
            Color.FromArgb(20, 30, 48),
            Color.FromArgb(17, 48, 76),
            LinearGradientMode.ForwardDiagonal
        );
        using var border = new Pen(Color.FromArgb(72, 98, 132), 1.2f);
        e.Graphics.FillPath(gradient, path);

        using var clipRegion = new Region(path);
        var previousClip = e.Graphics.Clip;
        e.Graphics.SetClip(clipRegion, CombineMode.Replace);

        using var glowA = new SolidBrush(Color.FromArgb(64, AccentColorA));
        using var glowB = new SolidBrush(Color.FromArgb(58, AccentColorB));
        e.Graphics.FillEllipse(glowA, new Rectangle(bounds.Width - 210, -40, 260, 260));
        e.Graphics.FillEllipse(glowB, new Rectangle(-90, bounds.Height - 210, 250, 250));

        using var linePen = new Pen(Color.FromArgb(18, 255, 255, 255), 1f);
        for (var offset = -bounds.Height; offset < bounds.Width; offset += 28)
        {
            e.Graphics.DrawLine(linePen, offset, 0, offset + bounds.Height, bounds.Height);
        }

        e.Graphics.Clip = previousClip;
        e.Graphics.DrawPath(border, path);
    }
}

internal sealed class LauncherBadge : Control
{
    [Browsable(false)]
    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public Color FillColor { get; set; } = Color.FromArgb(26, 42, 63);
    [Browsable(false)]
    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public Color BorderColor { get; set; } = Color.FromArgb(73, 103, 143);
    [Browsable(false)]
    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public Color BadgeTextColor { get; set; } = Color.FromArgb(220, 236, 255);

    public LauncherBadge()
    {
        DoubleBuffered = true;
        Size = new Size(132, 34);
        Font = new Font("Segoe UI Semibold", 9.2f, FontStyle.Bold, GraphicsUnit.Point);
        ForeColor = BadgeTextColor;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        var bounds = ClientRectangle;
        bounds.Width -= 1;
        bounds.Height -= 1;

        using var path = LauncherDrawing.CreateRoundedPath(bounds, Math.Min(16, bounds.Height / 2));
        using var fill = new SolidBrush(FillColor);
        using var border = new Pen(BorderColor, 1f);
        using var textBrush = new SolidBrush(BadgeTextColor);
        e.Graphics.FillPath(fill, path);
        e.Graphics.DrawPath(border, path);
        TextRenderer.DrawText(
            e.Graphics,
            Text,
            Font,
            bounds,
            BadgeTextColor,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis
        );
    }
}

internal sealed class LauncherAccentButton : Button
{
    private bool _hovered;
    private bool _pressed;

    public LauncherAccentButton()
    {
        DoubleBuffered = true;
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        BackColor = Color.Transparent;
        ForeColor = Color.FromArgb(12, 20, 31);
        Font = new Font("Segoe UI Semibold", 15f, FontStyle.Bold, GraphicsUnit.Point);
        Cursor = Cursors.Hand;
        Size = new Size(250, 58);
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
    }

    protected override void OnMouseEnter(EventArgs e)
    {
        _hovered = true;
        Invalidate();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        _hovered = false;
        _pressed = false;
        Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnMouseDown(MouseEventArgs mevent)
    {
        _pressed = true;
        Invalidate();
        base.OnMouseDown(mevent);
    }

    protected override void OnMouseUp(MouseEventArgs mevent)
    {
        _pressed = false;
        Invalidate();
        base.OnMouseUp(mevent);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        var bounds = ClientRectangle;
        bounds.Width -= 1;
        bounds.Height -= 1;

        var start = _pressed ? Color.FromArgb(69, 180, 245) : (_hovered ? Color.FromArgb(95, 214, 255) : Color.FromArgb(78, 202, 255));
        var end = _pressed ? Color.FromArgb(54, 125, 242) : (_hovered ? Color.FromArgb(65, 154, 255) : Color.FromArgb(57, 141, 255));

        using var path = LauncherDrawing.CreateRoundedPath(bounds, 20);
        using var brush = new LinearGradientBrush(bounds, start, end, LinearGradientMode.Horizontal);
        using var border = new Pen(Color.FromArgb(190, 255, 255, 255), 1.2f);
        e.Graphics.FillPath(brush, path);
        e.Graphics.DrawPath(border, path);

        TextRenderer.DrawText(
            e.Graphics,
            Text,
            Font,
            bounds,
            ForeColor,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter
        );
    }
}

internal sealed class LauncherGhostButton : Button
{
    private bool _hovered;

    public LauncherGhostButton()
    {
        DoubleBuffered = true;
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        BackColor = Color.Transparent;
        ForeColor = Color.FromArgb(218, 230, 244);
        Font = new Font("Segoe UI", 12f, FontStyle.Bold, GraphicsUnit.Point);
        Cursor = Cursors.Hand;
        Size = new Size(42, 34);
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
    }

    protected override void OnMouseEnter(EventArgs e)
    {
        _hovered = true;
        Invalidate();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        _hovered = false;
        Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        var bounds = ClientRectangle;
        bounds.Width -= 1;
        bounds.Height -= 1;

        using var path = LauncherDrawing.CreateRoundedPath(bounds, 14);
        using var fill = new SolidBrush(_hovered ? Color.FromArgb(40, 255, 255, 255) : Color.FromArgb(20, 255, 255, 255));
        using var border = new Pen(Color.FromArgb(_hovered ? 92 : 55, 255, 255, 255), 1f);
        e.Graphics.FillPath(fill, path);
        e.Graphics.DrawPath(border, path);

        TextRenderer.DrawText(
            e.Graphics,
            Text,
            Font,
            bounds,
            ForeColor,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter
        );
    }
}

internal sealed class LauncherActivityBar : Control
{
    private readonly System.Windows.Forms.Timer _timer;
    private int _offset;
    private bool _active;

    [Browsable(false)]
    [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
    public bool Active
    {
        get => _active;
        set
        {
            _active = value;
            _timer.Enabled = value;
            Invalidate();
        }
    }

    public LauncherActivityBar()
    {
        DoubleBuffered = true;
        Size = new Size(320, 12);
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);

        _timer = new System.Windows.Forms.Timer
        {
            Interval = 36,
        };
        _timer.Tick += (_, _) =>
        {
            _offset = (_offset + 10) % Math.Max(64, Width + 80);
            Invalidate();
        };
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        var bounds = ClientRectangle;
        bounds.Width -= 1;
        bounds.Height -= 1;

        using var path = LauncherDrawing.CreateRoundedPath(bounds, Math.Min(8, bounds.Height / 2));
        using var track = new SolidBrush(Color.FromArgb(26, 48, 70));
        using var border = new Pen(Color.FromArgb(66, 95, 124), 1f);
        e.Graphics.FillPath(track, path);
        e.Graphics.DrawPath(border, path);

        if (!_active)
        {
            using var idle = new SolidBrush(Color.FromArgb(90, 89, 195, 255));
            var idleRect = new Rectangle(1, 1, Math.Max(18, Width / 6), Math.Max(2, Height - 2));
            using var idlePath = LauncherDrawing.CreateRoundedPath(idleRect, Math.Min(6, idleRect.Height / 2));
            e.Graphics.FillPath(idle, idlePath);
            return;
        }

        var segmentWidth = Math.Max(64, Width / 3);
        var x = (_offset % (Width + segmentWidth)) - segmentWidth;
        var glowRect = new Rectangle(x, 1, segmentWidth, Math.Max(2, Height - 2));
        using var glowBrush = new LinearGradientBrush(
            glowRect,
            Color.FromArgb(40, 89, 195, 255),
            Color.FromArgb(220, 89, 195, 255),
            LinearGradientMode.Horizontal
        );
        using var glowPath = LauncherDrawing.CreateRoundedPath(glowRect, Math.Min(6, glowRect.Height / 2));
        e.Graphics.FillPath(glowBrush, glowPath);
    }
}
