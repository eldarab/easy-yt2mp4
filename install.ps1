# Installs "Save YouTube Video" for the current Windows user. No admin rights needed.
#
#   irm https://raw.githubusercontent.com/eldarab/easy-yt2mp4/main/install.ps1 | iex
#
# Downloads the latest release into %LOCALAPPDATA%\easy-yt2mp4\app and puts a
# "Save YouTube Video" icon on the desktop. Running it again updates the app.
# yt-dlp, ffmpeg and Deno are set up by the app itself the first time it opens.

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $zipUrl = $env:EASYYT_RELEASE_ZIP
    if (-not $zipUrl) { $zipUrl = 'https://github.com/eldarab/easy-yt2mp4/releases/latest/download/easy-yt2mp4.zip' }
    $root = $env:EASYYT_HOME
    if (-not $root) { $root = Join-Path $env:LOCALAPPDATA 'easy-yt2mp4' }
    $appDir = Join-Path $root 'app'
    $desktop = $env:EASYYT_DESKTOP
    if (-not $desktop) { $desktop = [Environment]::GetFolderPath('Desktop') }
    $shortcutPath = Join-Path $desktop 'Save YouTube Video.lnk'

    Write-Host 'Installing Save YouTube Video...'
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('easy-yt2mp4-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    try {
        $zip = Join-Path $temp 'app.zip'
        if (Test-Path -LiteralPath $zipUrl) {
            Copy-Item -LiteralPath $zipUrl -Destination $zip
        } else {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
        }
        $unpacked = Join-Path $temp 'app'
        Expand-Archive -LiteralPath $zip -DestinationPath $unpacked -Force
        if (-not (Test-Path -LiteralPath (Join-Path $unpacked 'SaveYouTubeVideo.ps1'))) {
            throw 'The download does not contain SaveYouTubeVideo.ps1'
        }

        New-Item -ItemType Directory -Force -Path $root | Out-Null
        if (Test-Path -LiteralPath $appDir) { Remove-Item -LiteralPath $appDir -Recurse -Force }
        Move-Item -LiteralPath $unpacked -Destination $appDir
        Get-ChildItem -LiteralPath $appDir -Recurse -File | Unblock-File

        $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $script = Join-Path $appDir 'SaveYouTubeVideo.ps1'
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcutPath)
        $link.TargetPath = $powershell
        $link.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $script
        $link.WorkingDirectory = $appDir
        $link.IconLocation = (Join-Path $appDir 'icon.ico') + ',0'
        $link.Description = 'Save a YouTube video to the Videos folder'
        $link.Save()
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)

        $version = (Get-Content -LiteralPath (Join-Path $appDir 'VERSION') -TotalCount 1).Trim()
        Write-Host ''
        Write-Host "Done. Save YouTube Video $version is installed." -ForegroundColor Green
        Write-Host "Double-click 'Save YouTube Video' on the desktop to open it."
    } catch {
        Write-Host ''
        Write-Host "The install did not finish: $_" -ForegroundColor Red
        Write-Host 'Check the internet connection and run the command again.'
    } finally {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
