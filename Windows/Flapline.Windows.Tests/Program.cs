using Flapline.Windows;

foreach (var character in FlaplineCore.Drum)
{
    var successor = FlaplineCore.IdleSuccessor(character);
    var sourceIndex = Array.IndexOf(FlaplineCore.Drum, character);
    var targetIndex = Array.IndexOf(FlaplineCore.Drum, successor);
    Assert(targetIndex == (sourceIndex + 1) % FlaplineCore.Drum.Length, "Idle drift skipped a drum position.");
}
Assert(FlaplineCore.IdleSuccessor("🚆") == " ", "Unicode idle drift must settle to blank in one direct transition.");

var targets = FlaplineCore.TextTargets(new[] { "HI" }, 5, 7);
Assert(targets[2, 2] == "H" && targets[2, 3] == "I", "Text should be centered inside the one-cell border.");
Assert(targets[0, 0] == " ", "Text layout must preserve the one-cell border.");

Assert(ScreenSaverCommand.Parse(new[] { "/s" }).Mode == ScreenSaverMode.FullScreen, "/s parsing failed.");
var preview = ScreenSaverCommand.Parse(new[] { "/p", "1234" });
Assert(preview.Mode == ScreenSaverMode.Preview && preview.PreviewHandle == 1234, "/p parsing failed.");
Assert(ScreenSaverCommand.Parse(Array.Empty<string>()).Mode == ScreenSaverMode.Configure, "Default mode must configure.");

static void Assert(bool condition, string message)
{
    if (!condition)
    {
        throw new InvalidOperationException(message);
    }
}
