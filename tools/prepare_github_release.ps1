param(
    [string]$Version = "1.2.1"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildRoot = Join-Path $ProjectRoot "builds"
$ReleaseRoot = Join-Path $BuildRoot "release"
$GamePath = Join-Path $BuildRoot "VoxelRTXGame.exe"
$LauncherPath = Join-Path $BuildRoot "VoxelRTXLauncher.exe"
$RuntimeRoot = Join-Path $ProjectRoot "distribution"
$RuntimeGameRoot = Join-Path $RuntimeRoot "game"
$RuntimeLauncherRoot = Join-Path $RuntimeRoot "launcher"
$RuntimeManifestRoot = Join-Path $RuntimeRoot "manifests"
$RuntimeLegalRoot = Join-Path $RuntimeRoot "legal"
$LauncherManifestPath = Join-Path $RuntimeManifestRoot "manifest.json"
$LauncherSelfManifestPath = Join-Path $RuntimeManifestRoot "launcher_manifest.json"
$RuntimeLauncherPath = Join-Path $RuntimeLauncherRoot "VoxelRTXLauncher.exe"
$RuntimeLicensePath = Join-Path $RuntimeLegalRoot "LICENSE.txt"
$NotesPath = Join-Path $ReleaseRoot "release_notes.md"

foreach ($path in @($GamePath, $LauncherPath, $LauncherManifestPath, $LauncherSelfManifestPath)) {
    if (-not (Test-Path $path)) {
        throw "Required build artifact not found: $path"
    }
}

New-Item -ItemType Directory -Force -Path $ReleaseRoot | Out-Null
New-Item -ItemType Directory -Force -Path $RuntimeGameRoot, $RuntimeLauncherRoot, $RuntimeManifestRoot, $RuntimeLegalRoot | Out-Null

$ReleaseGamePath = Join-Path $ReleaseRoot "VoxelRTXGame.exe"
$ReleaseLauncherPath = Join-Path $ReleaseRoot "VoxelRTXLauncher.exe"
$ReleaseManifestPath = Join-Path $ReleaseRoot "manifest.json"
$ReleaseLauncherSelfManifestPath = Join-Path $ReleaseRoot "launcher_manifest.json"

Copy-Item -LiteralPath $GamePath -Destination $ReleaseGamePath -Force
Copy-Item -LiteralPath $LauncherPath -Destination $ReleaseLauncherPath -Force
Copy-Item -LiteralPath $LauncherManifestPath -Destination $ReleaseManifestPath -Force
Copy-Item -LiteralPath $LauncherSelfManifestPath -Destination $ReleaseLauncherSelfManifestPath -Force
Copy-Item -LiteralPath $LauncherPath -Destination $RuntimeLauncherPath -Force
Copy-Item -LiteralPath (Join-Path $ProjectRoot "LICENSE.txt") -Destination $RuntimeLicensePath -Force

$GameHash = (Get-FileHash -LiteralPath $ReleaseGamePath -Algorithm SHA256).Hash
$LauncherHash = (Get-FileHash -LiteralPath $ReleaseLauncherPath -Algorithm SHA256).Hash
$GameSizeBytes = (Get-Item -LiteralPath $ReleaseGamePath).Length
$LauncherSizeBytes = (Get-Item -LiteralPath $ReleaseLauncherPath).Length

$Notes = @"
# Voxel RTX Release $Version

- GitHub release tag: `v$Version`
- Game asset required by the external launcher: `VoxelRTXGame.exe`
- External launcher asset: `VoxelRTXLauncher.exe`
- Game manifest file: `manifest.json`
- Runtime manifests: `distribution/manifests/manifest.json` and `distribution/manifests/launcher_manifest.json`
- Runtime launcher binary: `distribution/launcher/VoxelRTXLauncher.exe`
- Runtime legal file: `distribution/legal/LICENSE.txt`

## SHA256

- `VoxelRTXGame.exe`: `$GameHash`
- `VoxelRTXLauncher.exe`: `$LauncherHash`

## Sizes

- `VoxelRTXGame.exe`: `$GameSizeBytes` bytes
- `VoxelRTXLauncher.exe`: `$LauncherSizeBytes` bytes

Le feed GitHub vital est maintenant `distribution/game`, `distribution/launcher`, `distribution/manifests` et `distribution/legal`.
Le launcher installe `VoxelRTXGame.exe` dans `%LocalAppData%\Programs\VoxelRTX`, telecharge les parties du jeu, recompose l'executable final, puis demarre le jeu avec le secure launch key/token flow.
"@

Set-Content -LiteralPath $NotesPath -Value $Notes -Encoding UTF8

Write-Output "Prepared game asset: $ReleaseGamePath"
Write-Output "Prepared launcher asset: $ReleaseLauncherPath"
Write-Output "Prepared launcher manifest: $ReleaseManifestPath"
Write-Output "Release notes: $NotesPath"
