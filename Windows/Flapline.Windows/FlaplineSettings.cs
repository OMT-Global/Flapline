using System;
using System.Linq;

namespace Flapline.Windows;

public enum FlaplineDisplayMode
{
    Messages,
    Random,
    Clock,
    Date
}

public enum FlaplineTheme
{
    Classic,
    Terminal,
    Monochrome
}

public sealed class FlaplineSettings
{
    public const double MinimumMessageHoldSeconds = 0;
    public const double MaximumMessageHoldSeconds = 30;
    public const double MinimumInterWaveDelaySeconds = 2;
    public const double MaximumInterWaveDelaySeconds = 60;
    public const int MinimumTargetRows = 4;
    public const int MaximumTargetRows = 24;

    public FlaplineDisplayMode DisplayMode { get; set; } = FlaplineDisplayMode.Messages;
    public string MessageText { get; set; } = "Flapline\nUnicode OK\nHello World";
    public double MessageHoldSeconds { get; set; } = 4;
    public double InterWaveDelaySeconds { get; set; } = 8;
    public bool IdleShuffleEnabled { get; set; } = true;
    public int TargetRows { get; set; } = 9;
    public FlaplineTheme Theme { get; set; } = FlaplineTheme.Classic;

    public void Normalize()
    {
        MessageText = string.IsNullOrWhiteSpace(MessageText) ? "Flapline" : MessageText;
        MessageHoldSeconds = Math.Clamp(MessageHoldSeconds, MinimumMessageHoldSeconds, MaximumMessageHoldSeconds);
        InterWaveDelaySeconds = Math.Clamp(
            InterWaveDelaySeconds,
            MinimumInterWaveDelaySeconds,
            MaximumInterWaveDelaySeconds
        );
        TargetRows = Math.Clamp(TargetRows, MinimumTargetRows, MaximumTargetRows);
    }

    public string[] Messages => MessageText
        .Split(new[] { "\r\n", "\n", "\r" }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
        .DefaultIfEmpty("Flapline")
        .ToArray();
}
