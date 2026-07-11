[CmdletBinding()]
param(
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64",
    [string]$ScreenSaverPath
)

$ErrorActionPreference = "Stop"
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script from an elevated PowerShell window."
}

if (-not $ScreenSaverPath) {
    $ScreenSaverPath = Join-Path (Split-Path -Parent $PSScriptRoot) "artifacts\$Runtime\Flapline.scr"
}
if (-not (Test-Path $ScreenSaverPath)) {
    throw "Screen saver not found at $ScreenSaverPath. Run Windows\build.ps1 first."
}

$destination = Join-Path $env:WINDIR "System32\Flapline.scr"
Copy-Item $ScreenSaverPath $destination -Force
Write-Host "Installed Flapline to $destination"
Start-Process control.exe -ArgumentList "desk.cpl,,1"
