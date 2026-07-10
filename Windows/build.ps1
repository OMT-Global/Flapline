[CmdletBinding()]
param(
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $PSScriptRoot "Flapline.Windows\Flapline.Windows.csproj"
$tests = Join-Path $PSScriptRoot "Flapline.Windows.Tests\Flapline.Windows.Tests.csproj"
$output = Join-Path $root "artifacts\$Runtime"

dotnet run --project $tests --configuration Release
dotnet publish $project `
    --configuration Release `
    --runtime $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:DebugType=None `
    --output $output

Copy-Item (Join-Path $output "Flapline.exe") (Join-Path $output "Flapline.scr") -Force
Write-Host "Built $output\Flapline.scr"
