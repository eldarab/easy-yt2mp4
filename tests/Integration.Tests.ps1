# End-to-end tests: run the real app against YouTube in a throwaway folder.
# Needs internet; downloads yt-dlp, ffmpeg and Deno (about 150 MB) and a few videos.
# Nothing touches the real Videos folder or desktop.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\Integration.Tests.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

$repo = Split-Path -Parent $PSScriptRoot
$app = Join-Path $repo 'src\SaveYouTubeVideo.ps1'
$base = New-TestFolder
$home1 = Join-Path $base 'home'
$videos = Join-Path $base 'Videos'
New-Item -ItemType Directory -Path $videos | Out-Null
Write-Host "Test folder: $base"

$ZooUrl = 'https://www.youtube.com/watch?v=jNQXAC9IVRw'      # "Me at the zoo": 19 s, 240p only
$BunnyUrl = 'https://youtu.be/aqz-KE-bpKQ'                    # Big Buck Bunny (CC BY 3.0), has 720p

function Invoke-App {
    param([string]$Url, [hashtable]$Env = @{}, [string]$AppHome = $home1)
    $names = @('HOME', 'VIDEOS', 'NO_WAIT', 'NO_EXPLORER') + @($Env.Keys)
    $saved = @{}
    foreach ($n in $names) { $saved[$n] = [Environment]::GetEnvironmentVariable("EASYYT_$n") }
    try {
        $env:EASYYT_HOME = $AppHome; $env:EASYYT_VIDEOS = $videos; $env:EASYYT_NO_WAIT = '1'; $env:EASYYT_NO_EXPLORER = '1'
        foreach ($k in $Env.Keys) { [Environment]::SetEnvironmentVariable("EASYYT_$k", $Env[$k]) }
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $ErrorActionPreference = 'Continue'
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $app -Url $Url 2>&1 | Out-String
        $code = $LASTEXITCODE
        return @{ Code = $code; Output = $output; Seconds = $watch.Elapsed.TotalSeconds }
    } finally {
        foreach ($n in $names) { [Environment]::SetEnvironmentVariable("EASYYT_$n", $saved[$n]) }
    }
}

function Get-Streams {
    param([string]$File)
    $probe = Join-Path $home1 'bin\ffprobe.exe'
    $json = & $probe -v error -show_entries 'stream=codec_type,codec_name,height' -of json $File | Out-String
    return ($json | ConvertFrom-Json).streams
}

function Get-VideoFiles { return @(Get-ChildItem -LiteralPath $videos -File | Sort-Object Name) }

try {
    Describe 'First-time setup, then a video without 720p falls back to H.264 up to 1080p' {
        $r = Invoke-App $ZooUrl
        Write-Host "  took $([int]$r.Seconds) s"
        Assert-Equal 0 $r.Code ("exit code; output:`n" + $r.Output)
        Assert-True ($r.Output -match 'The app is updating\. Please wait a moment\.') 'shows the updating message'
        Assert-True ($r.Output -match 'Saving the video') 'shows that saving started'
        foreach ($exe in 'yt-dlp.exe', 'ffmpeg.exe', 'ffprobe.exe', 'deno.exe') {
            Assert-True (Test-Path (Join-Path $home1 "bin\$exe")) "$exe is set up"
        }
        $file = Join-Path $videos 'Me at the zoo.mp4'
        Assert-True (Test-Path -LiteralPath $file) 'saved as "Me at the zoo.mp4"'
        $s = Get-Streams $file
        Assert-True (@($s | Where-Object { $_.codec_type -eq 'video' }).Count -eq 1) 'has moving picture'
        Assert-True (@($s | Where-Object { $_.codec_type -eq 'audio' }).Count -eq 1) 'has sound'
        Assert-Equal 'h264' (@($s | Where-Object { $_.codec_type -eq 'video' })[0].codec_name) 'H.264 video'
        Assert-Equal 'aac' (@($s | Where-Object { $_.codec_type -eq 'audio' })[0].codec_name) 'AAC audio'
        Assert-Equal 0 @(Get-ChildItem -LiteralPath (Join-Path $home1 'work') -Force).Count 'work folder is left empty'
    }

    Describe 'A file with the same name already exists' {
        $first = Join-Path $videos 'Me at the zoo.mp4'
        $hash = (Get-FileHash -LiteralPath $first).Hash
        $r = Invoke-App $ZooUrl -Env @{ LONG_SECONDS = '1' }
        Assert-Equal 0 $r.Code ("exit code; output:`n" + $r.Output)
        Assert-True (Test-Path -LiteralPath (Join-Path $videos 'Me at the zoo (2).mp4')) 'saved as "Me at the zoo (2).mp4"'
        Assert-Equal $hash (Get-FileHash -LiteralPath $first).Hash 'existing file is unchanged'
        Assert-True ($r.Output -match 'Saving is taking longer than usual') 'shows the taking-longer message (threshold set to 1 s)'
    }

    Describe 'A video with 720p is saved in 720p H.264 and AAC' {
        $r = Invoke-App $BunnyUrl
        Write-Host "  took $([int]$r.Seconds) s"
        Assert-Equal 0 $r.Code ("exit code; output:`n" + $r.Output)
        $file = Get-VideoFiles | Where-Object { $_.Name -like 'Big Buck Bunny*' } | Select-Object -First 1
        Assert-True ($null -ne $file) 'Big Buck Bunny file saved'
        if ($file) {
            Assert-Equal '.mp4' $file.Extension
            $s = Get-Streams $file.FullName
            $v = @($s | Where-Object { $_.codec_type -eq 'video' })[0]
            Assert-Equal 720 ([int]$v.height) '720p'
            Assert-Equal 'h264' $v.codec_name 'H.264'
            Assert-Equal 'aac' (@($s | Where-Object { $_.codec_type -eq 'audio' })[0].codec_name) 'AAC'
        }
    }

    Describe 'Not a YouTube link' {
        $before = (Get-VideoFiles).Count
        foreach ($text in @('hello there', 'https://vimeo.com/76979871')) {
            $r = Invoke-App $text
            Assert-Equal 2 $r.Code "exit code for '$text'"
            Assert-True ($r.Output -match 'This is not a link to a YouTube video') 'shows the not-a-link message'
        }
        Assert-Equal $before (Get-VideoFiles).Count 'nothing saved'
    }

    Describe 'A video that is no longer on YouTube' {
        $before = (Get-VideoFiles).Count
        $r = Invoke-App 'https://www.youtube.com/watch?v=aaaaaaaaaaa'
        Write-Host "  took $([int]$r.Seconds) s including the update check"
        Assert-Equal 3 $r.Code ("exit code; output:`n" + $r.Output)
        Assert-True ($r.Output -match "This video can't be saved because it is private") 'shows the unavailable message'
        Assert-Equal $before (Get-VideoFiles).Count 'nothing saved'
    }

    Describe 'The internet is off when saving starts' {
        $r = Invoke-App $ZooUrl -Env @{ PROBE_HOSTS = 'no-such-host.invalid' }
        Assert-Equal 4 $r.Code ("exit code; output:`n" + $r.Output)
        Assert-True ($r.Output -match 'The internet stopped working') 'shows the internet message'
    }

    Describe 'yt-dlp is updated when the app opens' {
        $ytdlp = Join-Path $home1 'bin\yt-dlp.exe'
        $latest = (& $ytdlp --version | Out-String).Trim()
        & "$env:SystemRoot\System32\curl.exe" -sSL --fail -o $ytdlp 'https://github.com/yt-dlp/yt-dlp/releases/download/2025.10.22/yt-dlp.exe'
        Assert-Equal '2025.10.22' (& $ytdlp --version | Out-String).Trim() 'older yt-dlp in place'
        $r = Invoke-App 'not a link'
        Assert-True ($r.Output -match 'The app is updating') 'shows the updating message'
        Assert-Equal $latest (& $ytdlp --version | Out-String).Trim() 'yt-dlp is the newest version again'
    }

    Describe 'First-time setup fails while the internet works' {
        $r = Invoke-App $ZooUrl -AppHome (Join-Path $base 'home-bad') -Env @{ URL_DENO = 'https://github.com/eldarab/easy-yt2mp4/releases/download/none/missing.zip' }
        Assert-Equal 10 $r.Code ("exit code; output:`n" + $r.Output)
        Assert-True ($r.Output -match "The app couldn't get ready\. Please close it") 'shows the setup message'
    }

    Describe 'First-time setup fails because the internet is off' {
        $r = Invoke-App $ZooUrl -AppHome (Join-Path $base 'home-offline') -Env @{ URL_YTDLP = 'https://no-such-host.invalid/yt-dlp.exe'; PROBE_HOSTS = 'no-such-host.invalid' }
        Assert-Equal 9 $r.Code ("exit code; output:`n" + $r.Output)
        Assert-True ($r.Output -match "because the internet isn't working") 'shows the setup internet message'
    }

    Describe 'install.ps1 installs the built release and makes a desktop icon' {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\Build-Release.ps1') -Version 0.0.1 | Out-Null
        $desk = Join-Path $base 'Desktop'
        New-Item -ItemType Directory -Path $desk | Out-Null
        $instHome = Join-Path $base 'home-install'
        $env:EASYYT_RELEASE_ZIP = Join-Path $repo 'dist\easy-yt2mp4.zip'; $env:EASYYT_HOME = $instHome; $env:EASYYT_DESKTOP = $desk
        try {
            $out = & powershell.exe -NoProfile -Command "iex (Get-Content -Raw '$repo\install.ps1')" 2>&1 | Out-String
            Assert-True ($out -match 'Done\. Save YouTube Video 0\.0\.1 is installed') ("install output:`n" + $out)
            $lnk = Join-Path $desk 'Save YouTube Video.lnk'
            Assert-True (Test-Path -LiteralPath $lnk) 'desktop icon exists'
            $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
            Assert-True ($sc.TargetPath -match 'WindowsPowerShell\\v1\.0\\powershell\.exe$') 'runs Windows PowerShell'
            Assert-True ($sc.Arguments -match '^-NoProfile -ExecutionPolicy Bypass -File ".+SaveYouTubeVideo\.ps1"$') "arguments: $($sc.Arguments)"
            Assert-True ($sc.IconLocation -match 'icon\.ico,0$') 'uses the app icon'
            Assert-True (Test-Path (Join-Path $instHome 'app\SaveYouTubeVideo.ps1')) 'app installed under the app folder'
            $out = & powershell.exe -NoProfile -Command "iex (Get-Content -Raw '$repo\uninstall.ps1')" 2>&1 | Out-String
            Assert-True (-not (Test-Path -LiteralPath $lnk)) 'uninstall removes the icon'
            Assert-True (-not (Test-Path -LiteralPath $instHome)) 'uninstall removes the app folder'
        } finally {
            Remove-Item Env:\EASYYT_RELEASE_ZIP, Env:\EASYYT_HOME, Env:\EASYYT_DESKTOP -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath (Join-Path $repo 'dist') -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} finally {
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
}

Complete-Tests
