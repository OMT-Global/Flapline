using System;
using System.Windows;
using System.Windows.Controls;

namespace Flapline.Windows;

internal sealed class SettingsWindow : Window
{
    private readonly FlaplineSettings settings;
    private readonly ComboBox mode = new();
    private readonly TextBox messages = new();
    private readonly Slider hold = Slider(
        FlaplineSettings.MinimumMessageHoldSeconds,
        FlaplineSettings.MaximumMessageHoldSeconds
    );
    private readonly Slider interWaveDelay = Slider(
        FlaplineSettings.MinimumInterWaveDelaySeconds,
        FlaplineSettings.MaximumInterWaveDelaySeconds
    );
    private readonly CheckBox idle = new() { Content = "Shuffle idle panels between waves" };
    private readonly Slider rows = Slider(
        FlaplineSettings.MinimumTargetRows,
        FlaplineSettings.MaximumTargetRows
    );
    private readonly ComboBox theme = new();

    internal SettingsWindow(FlaplineSettings settings)
    {
        this.settings = settings;
        Title = "Flapline Options";
        Width = 560;
        Height = 610;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;

        mode.ItemsSource = Enum.GetValues<FlaplineDisplayMode>();
        theme.ItemsSource = Enum.GetValues<FlaplineTheme>();
        messages.AcceptsReturn = true;
        messages.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
        messages.Height = 150;
        messages.TextWrapping = TextWrapping.Wrap;

        mode.SelectedItem = settings.DisplayMode;
        messages.Text = settings.MessageText;
        hold.Value = settings.MessageHoldSeconds;
        interWaveDelay.Value = settings.InterWaveDelaySeconds;
        idle.IsChecked = settings.IdleShuffleEnabled;
        rows.Value = settings.TargetRows;
        theme.SelectedItem = settings.Theme;

        var form = new StackPanel { Margin = new Thickness(24) };
        form.Children.Add(Row("Display", mode));
        form.Children.Add(Block("Messages", messages));
        form.Children.Add(Row("Message hold", hold));
        form.Children.Add(Row("Time between waves", interWaveDelay));
        form.Children.Add(idle);
        form.Children.Add(Row("Board rows", rows));
        form.Children.Add(Row("Theme", theme));

        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 24, 0, 0)
        };
        var cancel = new Button { Content = "Cancel", Width = 88, Margin = new Thickness(0, 0, 10, 0) };
        var save = new Button { Content = "Save", Width = 88, IsDefault = true };
        cancel.Click += (_, _) => Close();
        save.Click += (_, _) => SaveAndClose();
        buttons.Children.Add(cancel);
        buttons.Children.Add(save);
        form.Children.Add(buttons);
        Content = form;
    }

    private void SaveAndClose()
    {
        settings.DisplayMode = mode.SelectedItem is FlaplineDisplayMode selectedMode
            ? selectedMode
            : FlaplineDisplayMode.Messages;
        settings.MessageText = messages.Text;
        settings.MessageHoldSeconds = Math.Round(hold.Value);
        settings.InterWaveDelaySeconds = Math.Round(interWaveDelay.Value);
        settings.IdleShuffleEnabled = idle.IsChecked == true;
        settings.TargetRows = (int)Math.Round(rows.Value);
        settings.Theme = theme.SelectedItem is FlaplineTheme selectedTheme
            ? selectedTheme
            : FlaplineTheme.Classic;
        SettingsStore.Save(settings);
        Close();
    }

    private static FrameworkElement Row(string label, FrameworkElement control)
    {
        control.Width = 320;
        control.Margin = new Thickness(12, 6, 0, 6);
        var panel = new StackPanel { Orientation = Orientation.Horizontal };
        panel.Children.Add(new TextBlock
        {
            Text = label,
            Width = 120,
            VerticalAlignment = VerticalAlignment.Center
        });
        panel.Children.Add(control);
        return panel;
    }

    private static FrameworkElement Block(string label, FrameworkElement control)
    {
        var panel = new StackPanel { Margin = new Thickness(0, 6, 0, 6) };
        panel.Children.Add(new TextBlock { Text = label, Margin = new Thickness(0, 0, 0, 6) });
        control.Width = 452;
        panel.Children.Add(control);
        return panel;
    }

    private static Slider Slider(double minimum, double maximum) => new()
    {
        Minimum = minimum,
        Maximum = maximum,
        TickFrequency = 1,
        IsSnapToTickEnabled = true
    };
}
