# Save YouTube Video - the app Ruth opens from her desktop.
# Run with: powershell.exe -NoProfile -ExecutionPolicy Bypass -File SaveYouTubeVideo.ps1 [-Url <link>]
param([string]$Url)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'EasyYt2Mp4.ps1')

try {
    $code = Start-App -Url $Url
} catch {
    Write-Log "Unexpected problem: $_ $($_.ScriptStackTrace)"
    Write-Say $script:Messages.Other 'Yellow'
    Wait-UntilClosed
    $code = $script:Outcomes.Other.Code
}
exit $code
