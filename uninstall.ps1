# Removes "Save YouTube Video": the desktop icon and %LOCALAPPDATA%\easy-yt2mp4.
# Saved videos in the Videos folder are not touched.
#
#   irm https://raw.githubusercontent.com/eldarab/easy-yt2mp4/main/uninstall.ps1 | iex

& {
    $ErrorActionPreference = 'Stop'
    $root = $env:EASYYT_HOME
    if (-not $root) { $root = Join-Path $env:LOCALAPPDATA 'easy-yt2mp4' }
    $desktop = $env:EASYYT_DESKTOP
    if (-not $desktop) { $desktop = [Environment]::GetFolderPath('Desktop') }
    $shortcutPath = Join-Path $desktop 'Save YouTube Video.lnk'
    try {
        if (Test-Path -LiteralPath $shortcutPath) { Remove-Item -LiteralPath $shortcutPath -Force }
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        Write-Host 'Save YouTube Video was removed. Saved videos were kept.' -ForegroundColor Green
    } catch {
        Write-Host "Could not remove everything: $_" -ForegroundColor Red
        Write-Host 'Close the Save YouTube Video window if it is open, then run the command again.'
    }
}
