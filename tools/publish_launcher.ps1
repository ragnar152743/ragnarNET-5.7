param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LauncherProject = Join-Path $ProjectRoot "launcher_app\VoxelRTXLauncher\VoxelRTXLauncher.csproj"
$OutputDir = Join-Path $ProjectRoot "builds"

dotnet publish $LauncherProject `
    -c $Configuration `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o $OutputDir
