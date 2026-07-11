using System;
using System.Collections.Generic;

namespace Flapline.Windows;

public enum ScreenSaverMode
{
    Configure,
    FullScreen,
    Preview
}

public readonly record struct ScreenSaverCommand(ScreenSaverMode Mode, nint PreviewHandle = 0)
{
    public static ScreenSaverCommand Parse(IReadOnlyList<string> arguments)
    {
        if (arguments.Count == 0)
        {
            return new(ScreenSaverMode.Configure);
        }

        var first = arguments[0].Trim();
        var parts = first.Split(new[] { ':', '=' }, 2);
        var option = parts[0].ToLowerInvariant();

        if (option is "/s" or "-s")
        {
            return new(ScreenSaverMode.FullScreen);
        }

        if (option is "/p" or "-p")
        {
            var handleText = parts.Length == 2
                ? parts[1]
                : arguments.Count > 1 ? arguments[1] : string.Empty;
            return long.TryParse(handleText, out var handle)
                ? new(ScreenSaverMode.Preview, (nint)handle)
                : new(ScreenSaverMode.Configure);
        }

        return new(ScreenSaverMode.Configure);
    }
}
