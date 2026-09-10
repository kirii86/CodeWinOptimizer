# Generates SHA256 of build/bin/CodeWinOptimizer.exe and uploads it
# to the matching GitHub release as <asset>.sha256.
#
# Usage:
#   .\scripts\publish-checksum.ps1 -Tag v1.2.2
#   (assumes the exe asset is already attached to the release as CodeWinOptimizer-<Tag>.exe)

param(
    [Parameter(Mandatory = $true)] [string] $Tag,
    [string] $Exe       = 'build/bin/CodeWinOptimizer.exe',
    [string] $AssetName = "CodeWinOptimizer-$Tag.exe",
    [string] $Repo      = 'oscarxdev/CodeWinOptimizer-App'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Exe)) {
    throw "Binary not found at $Exe. Build with 'wails build' first."
}

$hash = (Get-FileHash -Path $Exe -Algorithm SHA256).Hash.ToLowerInvariant()
$sumFile = "$AssetName.sha256"

"$hash  $AssetName" | Set-Content -Path $sumFile -Encoding ascii -NoNewline
Write-Host "Wrote $sumFile" -ForegroundColor Green
Write-Host "  $hash" -ForegroundColor DarkGray

# Se sube con la API usando 'Content-Type: text/plain' a proposito: con
# 'gh release upload' GitHub lo publica como application/octet-stream, y
# entonces Invoke-WebRequest en el instalador devuelve un byte[] en lugar de
# texto (rompia la verificacion del SHA256).
$releaseId = gh api "repos/$Repo/releases/tags/$Tag" --jq '.id'
if (-not $releaseId) { throw "Release '$Tag' no encontrada en $Repo." }

$existingId = gh api "repos/$Repo/releases/$releaseId/assets" --jq ('.[] | select(.name == "' + $sumFile + '") | .id')
if ($existingId) {
    gh api --method DELETE "repos/$Repo/releases/assets/$existingId" | Out-Null
}

# Ojo: el upload de assets tiene que ir contra uploads.github.com (contra
# api.github.com devuelve 404).
gh api --method POST -H 'Content-Type: text/plain' "https://uploads.github.com/repos/$Repo/releases/$releaseId/assets?name=$sumFile" --input $sumFile | Out-Null
Write-Host "Uploaded $sumFile to release $Tag as text/plain" -ForegroundColor Green

Remove-Item $sumFile -Force
