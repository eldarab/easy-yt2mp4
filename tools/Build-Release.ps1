# Builds dist\easy-yt2mp4.zip: the app files plus a VERSION file.
#   powershell -File tools\Build-Release.ps1 -Version 1.0.0
param([Parameter(Mandatory = $true)][string]$Version)
$ErrorActionPreference = 'Stop'

$Version = $Version.TrimStart('v')
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must look like 1.2.3, got '$Version'" }

$repo = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $repo 'dist'
$stage = Join-Path $dist 'easy-yt2mp4'
if (Test-Path -LiteralPath $dist) { Remove-Item -LiteralPath $dist -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

foreach ($name in @('SaveYouTubeVideo.ps1', 'EasyYt2Mp4.ps1', 'icon.ico')) {
    Copy-Item -LiteralPath (Join-Path $repo "src\$name") -Destination $stage
}
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination $stage
Set-Content -LiteralPath (Join-Path $stage 'VERSION') -Value $Version -Encoding Ascii

$zip = Join-Path $dist 'easy-yt2mp4.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
Write-Host "Built $zip ($Version)"
