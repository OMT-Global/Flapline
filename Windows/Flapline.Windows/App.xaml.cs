using System;
using System.Collections.Generic;
using System.Windows;

namespace Flapline.Windows;

public partial class App : System.Windows.Application
{
    private readonly List<ScreenSaverWindow> windows = new();

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        var command = ScreenSaverCommand.Parse(e.Args);
        var settings = SettingsStore.Load();

        switch (command.Mode)
        {
            case ScreenSaverMode.Configure:
                new SettingsWindow(settings).ShowDialog();
                Shutdown();
                break;

            case ScreenSaverMode.Preview when command.PreviewHandle != 0:
                ShowWindow(new ScreenSaverWindow(settings, command.PreviewHandle));
                break;

            case ScreenSaverMode.FullScreen:
                foreach (var screen in System.Windows.Forms.Screen.AllScreens)
                {
                    ShowWindow(new ScreenSaverWindow(settings, screen.Bounds));
                }
                break;

            default:
                new SettingsWindow(settings).ShowDialog();
                Shutdown();
                break;
        }
    }

    private void ShowWindow(ScreenSaverWindow window)
    {
        window.ExitRequested += ExitScreenSaver;
        window.Closed += (_, _) =>
        {
            windows.Remove(window);
            if (windows.Count == 0)
            {
                Shutdown();
            }
        };
        windows.Add(window);
        window.Show();
    }

    private void ExitScreenSaver()
    {
        foreach (var window in windows.ToArray())
        {
            window.Close();
        }
    }
}
