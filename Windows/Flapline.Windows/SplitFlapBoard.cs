using System;
using System.Collections.Generic;
using System.Globalization;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;

namespace Flapline.Windows;

internal sealed class SplitFlapBoard : FrameworkElement
{
    private const double Gap = 2;
    private static readonly TimeSpan FlipDuration = TimeSpan.FromMilliseconds(160);
    private static readonly TimeSpan IdleCadence = TimeSpan.FromMilliseconds(500);
    private static readonly TimeSpan FrameCadence = TimeSpan.FromMilliseconds(33);

    private readonly FlaplineSettings settings;
    private readonly Random random = new();
    private readonly DispatcherTimer scheduler;
    private readonly DispatcherTimer animationTimer;
    private readonly Dictionary<TextCacheKey, FormattedText> textCache = new();
    private readonly Palette palette;
    private readonly VisualCollection visuals;
    private CellState[,] cells = new CellState[0, 0];
    private DrawingVisual[,] cellVisuals = new DrawingVisual[0, 0];
    private DateTimeOffset nextContentUpdate;
    private DateTimeOffset nextIdleUpdate;
    private bool started;
    private int messageIndex;
    private int rows;
    private int columns;
    private double panelWidth;
    private double panelHeight;
    private double originX;
    private double originY;
    private double pixelsPerDip = 1;

    internal SplitFlapBoard(FlaplineSettings settings)
    {
        this.settings = settings;
        this.settings.Normalize();
        palette = Palette.For(settings.Theme);
        visuals = new VisualCollection(this);
        SnapsToDevicePixels = true;

        scheduler = new DispatcherTimer(DispatcherPriority.Background)
        {
            IsEnabled = false
        };
        scheduler.Tick += HandleSchedule;

        animationTimer = new DispatcherTimer(DispatcherPriority.Render)
        {
            Interval = FrameCadence,
            IsEnabled = false
        };
        animationTimer.Tick += HandleAnimationFrame;
        SizeChanged += (_, _) => RebuildGrid();
    }

    internal void Start()
    {
        if (started)
        {
            return;
        }

        started = true;
        RebuildGrid();
        var now = DateTimeOffset.Now;
        SetImmediate(CurrentTargets(advanceMessage: false));
        nextContentUpdate = NextContentDeadline(now);
        nextIdleUpdate = now + IdleCadence;
        ScheduleNextWake(now);
    }

    internal void Stop()
    {
        started = false;
        scheduler.Stop();
        animationTimer.Stop();
    }

    protected override int VisualChildrenCount => visuals.Count;

    protected override Visual GetVisualChild(int index) => visuals[index];

    private void RebuildGrid()
    {
        if (ActualWidth <= 0 || ActualHeight <= 0)
        {
            return;
        }

        rows = settings.TargetRows;
        panelHeight = Math.Max(12, Math.Floor((ActualHeight - Gap * (rows + 1)) / rows));
        panelWidth = Math.Max(8, Math.Floor(panelHeight * 0.62));
        columns = Math.Max(1, (int)Math.Floor((ActualWidth + Gap) / (panelWidth + Gap)));
        var totalWidth = columns * (panelWidth + Gap) - Gap;
        var totalHeight = rows * (panelHeight + Gap) - Gap;
        originX = Math.Floor((ActualWidth - totalWidth) / 2);
        originY = Math.Floor((ActualHeight - totalHeight) / 2);
        pixelsPerDip = VisualTreeHelper.GetDpi(this).PixelsPerDip;

        cells = new CellState[rows, columns];
        cellVisuals = new DrawingVisual[rows, columns];
        visuals.Clear();

        var background = new DrawingVisual();
        using (var context = background.RenderOpen())
        {
            context.DrawRectangle(palette.Screen, null, new Rect(RenderSize));
        }
        visuals.Add(background);

        for (var row = 0; row < rows; row++)
        {
            for (var column = 0; column < columns; column++)
            {
                cells[row, column] = new CellState();
                var visual = new DrawingVisual();
                cellVisuals[row, column] = visual;
                visuals.Add(visual);
            }
        }
        textCache.Clear();

        if (started)
        {
            SetImmediate(CurrentTargets(advanceMessage: false));
        }
        else
        {
            RenderAllCells(DateTimeOffset.Now);
        }
    }

    private void HandleSchedule(object? sender, EventArgs e)
    {
        scheduler.Stop();
        if (!started)
        {
            return;
        }

        var now = DateTimeOffset.Now;
        if (now >= nextContentUpdate)
        {
            StartWave(CurrentTargets(advanceMessage: true), now);
            nextContentUpdate = NextContentDeadline(now);
        }

        if (ShouldIdleShuffle && now >= nextIdleUpdate)
        {
            StartIdleDrift(now);
            nextIdleUpdate = now + IdleCadence;
        }

        ScheduleNextWake(now);
    }

    private void ScheduleNextWake(DateTimeOffset now)
    {
        if (!started)
        {
            return;
        }

        var deadline = nextContentUpdate;
        if (ShouldIdleShuffle && nextIdleUpdate < deadline)
        {
            deadline = nextIdleUpdate;
        }

        scheduler.Interval = TimeSpan.FromMilliseconds(Math.Max(10, (deadline - now).TotalMilliseconds));
        scheduler.Start();
    }

    private DateTimeOffset NextContentDeadline(DateTimeOffset now)
    {
        return settings.DisplayMode switch
        {
            FlaplineDisplayMode.Clock => new DateTimeOffset(
                now.Year,
                now.Month,
                now.Day,
                now.Hour,
                now.Minute,
                now.Second,
                now.Offset
            ).AddSeconds(1),
            FlaplineDisplayMode.Date => now.Date.AddDays(1),
            _ => now.AddSeconds(settings.MessageHoldSeconds + settings.InterWaveDelaySeconds)
        };
    }

    private string[,] CurrentTargets(bool advanceMessage)
    {
        switch (settings.DisplayMode)
        {
            case FlaplineDisplayMode.Random:
                return FlaplineCore.RandomTargets(rows, columns, random);
            case FlaplineDisplayMode.Clock:
                return FlaplineCore.TextTargets(new[] { DateTime.Now.ToString("HH:mm:ss") }, rows, columns);
            case FlaplineDisplayMode.Date:
                return FlaplineCore.TextTargets(new[] { DateTime.Now.ToString("d", CultureInfo.CurrentCulture) }, rows, columns);
            default:
                var messages = settings.Messages;
                if (advanceMessage)
                {
                    messageIndex = (messageIndex + 1) % messages.Length;
                }
                var selected = messages[messageIndex % messages.Length];
                return FlaplineCore.TextTargets(new[] { selected }, rows, columns);
        }
    }

    private void SetImmediate(string[,] targets)
    {
        for (var row = 0; row < rows; row++)
        {
            for (var column = 0; column < columns; column++)
            {
                cells[row, column].SetImmediate(targets[row, column]);
            }
        }
        RenderAllCells(DateTimeOffset.Now);
    }

    private void StartWave(string[,] targets, DateTimeOffset now)
    {
        for (var column = 0; column < columns; column++)
        {
            var columnDelay = TimeSpan.FromMilliseconds(column * 60);
            for (var row = 0; row < rows; row++)
            {
                var jitter = TimeSpan.FromMilliseconds(random.Next(0, 41));
                cells[row, column].Begin(targets[row, column], now + columnDelay + jitter, FlipDuration);
            }
        }
        StartAnimationTimerIfNeeded();
    }

    private void StartIdleDrift(DateTimeOffset now)
    {
        var available = rows * columns;
        var count = Math.Clamp((int)Math.Ceiling(available * 0.01), 1, 4);
        var selected = new HashSet<int>();
        var attempts = 0;

        while (selected.Count < count && attempts < available * 2)
        {
            attempts++;
            var index = random.Next(available);
            if (!selected.Add(index))
            {
                continue;
            }

            var row = index / columns;
            var column = index % columns;
            var cell = cells[row, column];
            if (cell.IsTransitioning)
            {
                continue;
            }
            cell.Begin(FlaplineCore.IdleSuccessor(cell.Current), now, FlipDuration);
        }
        StartAnimationTimerIfNeeded();
    }

    private void StartAnimationTimerIfNeeded()
    {
        if (!animationTimer.IsEnabled && HasTransitions())
        {
            animationTimer.Start();
        }
    }

    private void HandleAnimationFrame(object? sender, EventArgs e)
    {
        var now = DateTimeOffset.Now;
        var active = false;
        for (var row = 0; row < rows; row++)
        {
            for (var column = 0; column < columns; column++)
            {
                var cell = cells[row, column];
                if (!cell.IsTransitioning)
                {
                    continue;
                }

                cell.CompleteIfNeeded(now);
                RenderCell(row, column, now);
                active |= cell.IsTransitioning;
            }
        }
        if (!active)
        {
            animationTimer.Stop();
        }
    }

    private bool HasTransitions()
    {
        foreach (var cell in cells)
        {
            if (cell.IsTransitioning)
            {
                return true;
            }
        }
        return false;
    }

    private bool ShouldIdleShuffle => settings.IdleShuffleEnabled
        && settings.DisplayMode != FlaplineDisplayMode.Clock;

    private void RenderAllCells(DateTimeOffset now)
    {
        for (var row = 0; row < rows; row++)
        {
            for (var column = 0; column < columns; column++)
            {
                RenderCell(row, column, now);
            }
        }
    }

    private void RenderCell(int row, int column, DateTimeOffset now)
    {
        var rect = new Rect(
            originX + column * (panelWidth + Gap),
            originY + row * (panelHeight + Gap),
            panelWidth,
            panelHeight
        );
        using var context = cellVisuals[row, column].RenderOpen();
        DrawPanel(context, rect, cells[row, column], now);
    }

    private void DrawPanel(DrawingContext context, Rect rect, CellState cell, DateTimeOffset now)
    {
        context.DrawRoundedRectangle(palette.Panel, null, rect, 1.5, 1.5);
        var progress = cell.Progress(now);
        if (!cell.IsTransitioning || progress <= 0)
        {
            DrawCharacter(context, cell.Current, rect);
        }
        else
        {
            DrawCharacter(context, cell.Target, rect);
            var half = new Rect(rect.X, rect.Y, rect.Width, rect.Height / 2);
            var scale = progress < 0.5 ? 1 - progress * 2 : 1 - (progress - 0.5) * 2;
            if (progress >= 0.5)
            {
                half.Y += rect.Height / 2;
            }

            context.PushClip(new RectangleGeometry(half));
            context.PushTransform(new ScaleTransform(1, Math.Max(0.02, scale), rect.X + rect.Width / 2, rect.Y + rect.Height / 2));
            DrawCharacter(context, cell.Current, rect);
            context.Pop();
            context.Pop();
        }

        var seamY = rect.Y + rect.Height / 2;
        context.DrawLine(palette.Divider, new Point(rect.X, seamY), new Point(rect.Right, seamY));
    }

    private void DrawCharacter(DrawingContext context, string character, Rect rect)
    {
        var fontSize = Math.Max(8, rect.Height * 0.62);
        var key = new TextCacheKey(character, (int)Math.Round(fontSize * 10), (int)Math.Round(pixelsPerDip * 100));
        if (!textCache.TryGetValue(key, out var text))
        {
            text = new FormattedText(
                character,
                CultureInfo.CurrentCulture,
                FlowDirection.LeftToRight,
                new Typeface("Consolas"),
                fontSize,
                palette.Character,
                pixelsPerDip
            );
            textCache[key] = text;
        }

        context.DrawText(
            text,
            new Point(
                rect.X + (rect.Width - text.WidthIncludingTrailingWhitespace) / 2,
                rect.Y + (rect.Height - text.Height) / 2
            )
        );
    }

    private readonly record struct TextCacheKey(string Text, int FontSize, int Dpi);

    private sealed class CellState
    {
        internal string Current { get; private set; } = " ";
        internal string Target { get; private set; } = " ";
        internal DateTimeOffset Start { get; private set; }
        internal TimeSpan Duration { get; private set; } = FlipDuration;
        internal bool IsTransitioning => Current != Target;

        internal void SetImmediate(string value)
        {
            Current = value;
            Target = value;
        }

        internal void Begin(string target, DateTimeOffset start, TimeSpan duration)
        {
            if (target == Current)
            {
                Target = Current;
                return;
            }
            Target = target;
            Start = start;
            Duration = duration;
        }

        internal double Progress(DateTimeOffset now)
        {
            if (!IsTransitioning || now <= Start)
            {
                return 0;
            }
            return Math.Clamp((now - Start).TotalMilliseconds / Duration.TotalMilliseconds, 0, 1);
        }

        internal void CompleteIfNeeded(DateTimeOffset now)
        {
            if (IsTransitioning && now >= Start + Duration)
            {
                Current = Target;
            }
        }
    }

    private sealed record Palette(Brush Screen, Brush Panel, Brush Character, Pen Divider)
    {
        internal static Palette For(FlaplineTheme theme)
        {
            var colors = theme switch
            {
                FlaplineTheme.Terminal => (Screen: "#030706", Panel: "#050D0A", Character: "#59FF94", Divider: "#000504"),
                FlaplineTheme.Monochrome => (Screen: "#090909", Panel: "#141416", Character: "#F0F0E6", Divider: "#040405"),
                _ => (Screen: "#0D0B08", Panel: "#191713", Character: "#F6B73C", Divider: "#050403")
            };
            var screen = FrozenBrush(colors.Screen);
            var panel = FrozenBrush(colors.Panel);
            var character = FrozenBrush(colors.Character);
            var divider = new Pen(FrozenBrush(colors.Divider), 1);
            divider.Freeze();
            return new Palette(screen, panel, character, divider);
        }

        private static SolidColorBrush FrozenBrush(string color)
        {
            var brush = new SolidColorBrush((Color)ColorConverter.ConvertFromString(color));
            brush.Freeze();
            return brush;
        }
    }
}
