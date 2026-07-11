using System;
using System.Drawing;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;

namespace Flapline.Windows;

internal sealed class ScreenSaverWindow : Window
{
    private readonly SplitFlapBoard board;
    private readonly nint previewParent;
    private readonly Rectangle? screenBounds;
    private System.Windows.Point? initialMousePosition;
    private bool closingForInput;

    internal event Action? ExitRequested;

    private const long PreviewTopLevelStyles = NativeMethods.WsPopup
        | NativeMethods.WsCaption
        | NativeMethods.WsSysMenu
        | NativeMethods.WsThickFrame
        | NativeMethods.WsMinimizeBox
        | NativeMethods.WsMaximizeBox;

    internal ScreenSaverWindow(FlaplineSettings settings, nint previewParent)
        : this(settings)
    {
        this.previewParent = previewParent;
        Topmost = false;
        ShowActivated = false;
    }

    internal ScreenSaverWindow(FlaplineSettings settings, Rectangle screenBounds)
        : this(settings)
    {
        this.screenBounds = screenBounds;
    }

    private ScreenSaverWindow(FlaplineSettings settings)
    {
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        ShowActivated = true;
        Topmost = true;
        Background = System.Windows.Media.Brushes.Black;
        board = new SplitFlapBoard(settings);
        Content = board;

        SourceInitialized += HandleSourceInitialized;
        Loaded += (_, _) => board.Start();
        Closed += (_, _) =>
        {
            board.Stop();
            if (!IsPreview)
            {
                Mouse.OverrideCursor = null;
            }
        };
        PreviewKeyDown += (_, _) => RequestExit();
        MouseDown += (_, _) => RequestExit();
        MouseMove += HandleMouseMove;
    }

    private bool IsPreview => previewParent != 0;

    private void HandleSourceInitialized(object? sender, EventArgs e)
    {
        var handle = new WindowInteropHelper(this).Handle;
        if (IsPreview)
        {
            var previewStyle = (NativeMethods.GetWindowStyle(handle) | NativeMethods.WsChild)
                & ~PreviewTopLevelStyles;
            NativeMethods.SetWindowStyle(handle, previewStyle);
            _ = NativeMethods.SetWindowPos(
                handle,
                0,
                0,
                0,
                0,
                0,
                NativeMethods.SwpNoMove
                    | NativeMethods.SwpNoSize
                    | NativeMethods.SwpNoZOrder
                    | NativeMethods.SwpNoActivate
                    | NativeMethods.SwpFrameChanged
            );
            _ = NativeMethods.SetParent(handle, previewParent);
            if (NativeMethods.GetClientRect(previewParent, out var rectangle))
            {
                _ = NativeMethods.SetWindowPos(
                    handle,
                    0,
                    0,
                    0,
                    rectangle.Right - rectangle.Left,
                    rectangle.Bottom - rectangle.Top,
                    NativeMethods.SwpNoZOrder | NativeMethods.SwpNoActivate
                );
            }
            return;
        }

        if (screenBounds is { } bounds)
        {
            _ = NativeMethods.SetWindowPos(
                handle,
                0,
                bounds.X,
                bounds.Y,
                bounds.Width,
                bounds.Height,
                NativeMethods.SwpNoZOrder | NativeMethods.SwpNoActivate
            );
        }
        Mouse.OverrideCursor = Cursors.None;
    }

    private void HandleMouseMove(object sender, MouseEventArgs e)
    {
        if (IsPreview)
        {
            return;
        }

        var position = e.GetPosition(this);
        if (initialMousePosition is null)
        {
            initialMousePosition = position;
            return;
        }

        if (Math.Abs(position.X - initialMousePosition.Value.X) > 8
            || Math.Abs(position.Y - initialMousePosition.Value.Y) > 8)
        {
            RequestExit();
        }
    }

    private void RequestExit()
    {
        if (IsPreview || closingForInput)
        {
            return;
        }

        closingForInput = true;
        Mouse.OverrideCursor = null;
        ExitRequested?.Invoke();
    }
}
