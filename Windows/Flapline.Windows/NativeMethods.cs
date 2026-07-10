using System;
using System.Runtime.InteropServices;

namespace Flapline.Windows;

internal static class NativeMethods
{
    internal const int GwlStyle = -16;
    internal const long WsChild = 0x40000000L;
    internal const long WsPopup = 0x80000000L;
    internal const long WsCaption = 0x00C00000L;
    internal const long WsSysMenu = 0x00080000L;
    internal const long WsThickFrame = 0x00040000L;
    internal const long WsMinimizeBox = 0x00020000L;
    internal const long WsMaximizeBox = 0x00010000L;
    internal const uint SwpNoSize = 0x0001;
    internal const uint SwpNoMove = 0x0002;
    internal const uint SwpNoZOrder = 0x0004;
    internal const uint SwpNoActivate = 0x0010;
    internal const uint SwpFrameChanged = 0x0020;

    [StructLayout(LayoutKind.Sequential)]
    internal struct Rect
    {
        internal int Left;
        internal int Top;
        internal int Right;
        internal int Bottom;
    }

    [DllImport("user32.dll", SetLastError = true)]
    internal static extern nint SetParent(nint childWindow, nint newParent);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GetClientRect(nint window, out Rect rectangle);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetWindowPos(
        nint window,
        nint insertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags
    );

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW", SetLastError = true)]
    private static extern nint GetWindowLongPtr64(nint window, int index);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW", SetLastError = true)]
    private static extern int GetWindowLong32(nint window, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)]
    private static extern nint SetWindowLongPtr64(nint window, int index, nint value);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongW", SetLastError = true)]
    private static extern int SetWindowLong32(nint window, int index, int value);

    internal static long GetWindowStyle(nint window) => nint.Size == 8
        ? GetWindowLongPtr64(window, GwlStyle).ToInt64()
        : GetWindowLong32(window, GwlStyle);

    internal static void SetWindowStyle(nint window, long style)
    {
        if (nint.Size == 8)
        {
            _ = SetWindowLongPtr64(window, GwlStyle, (nint)style);
        }
        else
        {
            _ = SetWindowLong32(window, GwlStyle, (int)style);
        }
    }
}
