# Flapline for Windows

The Windows port is a native WPF screen saver with the standard Windows entry
points:

- `/s` opens the full-screen saver on every monitor.
- `/c` opens Flapline Options.
- `/p <HWND>` embeds a live preview in the Windows Screen Saver Settings pane.

It supports manual messages, random boards, clock and date modes, idle shuffle,
row density, and the classic, terminal, and monochrome themes. Settings stay in
`%LOCALAPPDATA%\Flapline\settings.json`.

## Build

Install the .NET 8 SDK on Windows, then run:

```powershell
.\Windows\build.ps1 -Runtime win-x64
```

Use `win-arm64` for Windows on Arm. The build runs the dependency-free core
tests and publishes a self-contained single-file screen saver to:

```text
artifacts\win-x64\Flapline.scr
```

## Install

From an elevated PowerShell window:

```powershell
.\Windows\install.ps1 -Runtime win-x64
```

The installer copies the `.scr` into `%WINDIR%\System32` and opens the Windows
Screen Saver Settings pane. Double-clicking the build artifact opens the same
options window without installing it.

## CPU behavior

The content scheduler sleeps until the next clock, message, date, or idle
deadline. A separate 30 fps render timer starts only while one or more panels
are transitioning and stops as soon as they settle, so a static board does not
continuously repaint.
