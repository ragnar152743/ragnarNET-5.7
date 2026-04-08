param(
    [string]$Version = "1.1.0"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildRoot = Join-Path $ProjectRoot "builds"
$ReleaseRoot = Join-Path $BuildRoot "release"
$GamePath = Join-Path $BuildRoot "VoxelRTXGame.exe"
$LauncherPath = Join-Path $BuildRoot "VoxelRTXLauncher.exe"
$LauncherManifestPath = Join-Path $ProjectRoot "launcher\manifest.json"
$NotesPath = Join-Path $ReleaseRoot "release_notes.md"

foreach ($path in @($GamePath, $LauncherPath, $LauncherManifestPath)) {
    if (-not (Test-Path $path)) {
        throw "Required build artifact not found: $path"
    }
}

New-Item -ItemType Directory -Force -Path $ReleaseRoot | Out-Null

$ReleaseGamePath = Join-Path $ReleaseRoot "VoxelRTXGame.exe"
$ReleaseLauncherPath = Join-Path $ReleaseRoot "VoxelRTXLauncher.exe"
$ReleaseManifestPath = Join-Path $ReleaseRoot "manifest.json"

Copy-Item -LiteralPath $GamePath -Destination $ReleaseGamePath -Force
Copy-Item -LiteralPath $LauncherPath -Destination $ReleaseLauncherPath -Force
Copy-Item -LiteralPath $LauncherManifestPath -Destination $ReleaseManifestPath -Force

$GameHash = (Get-FileHash -LiteralPath $ReleaseGamePath -Algorithm SHA256).Hash
$LauncherHash = (Get-FileHash -LiteralPath $ReleaseLauncherPath -Algorithm SHA256).Hash
$GameSizeBytes = (Get-Item -LiteralPath $ReleaseGamePath).Length
$LauncherSizeBytes = (Get-Item -LiteralPath $ReleaseLauncherPath).Length

$Notes = @"
# Voxel RTX Release $Version

- GitHub release tag: `v$Version`
- Game asset required by the external launcher: `VoxelRTXGame.exe`
- External launcher asset: `VoxelRTXLauncher.exe`
- Launcher manifest file: `manifest.json`

## SHA256

- `VoxelRTXGame.exe`: `$GameHash`
- `VoxelRTXLauncher.exe`: `$LauncherHash`

## Sizes

- `VoxelRTXGame.exe`: `$GameSizeBytes` bytes
- `VoxelRTXLauncher.exe`: `$LauncherSizeBytes` bytes

Upload both `.exe` files to the GitHub release.
Update `launcher/manifest.json` in `ragnar152743/ragnarNET-5.7` when you publish a new version.
The launcher installs `VoxelRTXGame.exe` into `%LocalAppData%\Programs\VoxelRTX`, checks GitHub, then starts the game with the secure launch key/token flow.
"@

Set-Content -LiteralPath $NotesPath -Value $Notes -Encoding UTF8

Write-Output "Prepared game asset: $ReleaseGamePath"
Write-Output "Prepared launcher asset: $ReleaseLauncherPath"
Write-Output "Prepared launcher manifest: $ReleaseManifestPath"
Write-Output "Release notes: $NotesPath"
