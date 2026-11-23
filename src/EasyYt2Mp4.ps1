# Functions for the "Save YouTube Video" app.
# Windows PowerShell 5.1. Keep this file ASCII only: 5.1 reads BOM-less files as ANSI.

Set-StrictMode -Version 2.0

# ---------------------------------------------------------------------------
# Words Ruth sees. The failure messages are approved by the product owner;
# changes go back to him.
# ---------------------------------------------------------------------------
$script:Messages = @{
    Updating       = 'The app is updating. Please wait a moment.'
    SetupNoNet     = "The app couldn't get ready because the internet isn't working. Please check that your internet is on, then open the app again."
    SetupOther     = "The app couldn't get ready. Please close it and open it again. If it happens again, ask someone to help you."
    NotALink       = 'This is not a link to a YouTube video. Please copy the link again from the YouTube page and paste it here.'
    Unavailable    = "This video can't be saved because it is private or no longer on YouTube. Please check that you can still watch it on YouTube."
    NoInternet     = 'The internet stopped working, so the video was not saved. Please check that your internet is on, then try again.'
    NoSpace        = "Your computer is too full to save this video. Please delete some files you don't need, or ask someone to help you, then try again."
    Blocked        = "YouTube isn't letting the app save this video right now. Please close the app, open it again, and try once more. If it still doesn't work, try again tomorrow."
    NoPictureSound = "The video couldn't be saved with both picture and sound, so nothing was saved. Please close the app, open it again, and try once more."
    Other          = 'Something went wrong and the video was not saved. Please close the app, open it again, and try once more. If it happens again, ask someone to help you.'
    TakingLong     = 'Saving is taking longer than usual. Please keep this window open and wait a little longer.'
    AskLink        = 'Paste the YouTube link here, then press Enter.'
    PasteHint      = '(To paste: hold the Ctrl key and press V, or click the right mouse button.)'
    Started        = 'Saving the video. Please wait...'
    Done           = 'Done! The video is saved in your Videos folder.'
}

# Exit code for each outcome, and whether the app asks for a link again.
# Messages that tell Ruth to close and reopen the app do not ask again.
$script:Outcomes = @{
    Saved          = @{ Code = 0;  AskAgain = $false }
    NotALink       = @{ Code = 2;  AskAgain = $true }
    Unavailable    = @{ Code = 3;  AskAgain = $true }
    NoInternet     = @{ Code = 4;  AskAgain = $true }
    NoSpace        = @{ Code = 5;  AskAgain = $true }
    Blocked        = @{ Code = 6;  AskAgain = $false }
    NoPictureSound = @{ Code = 7;  AskAgain = $false }
    Other          = @{ Code = 8;  AskAgain = $false }
    SetupNoNet     = @{ Code = 9;  AskAgain = $false }
    SetupOther     = @{ Code = 10; AskAgain = $false }
}

# Quality order from the ticket. Each stage is tried in turn; a stage is one
# yt-dlp run. Nothing is ever re-encoded: ffmpeg only merges and remuxes.
$script:FormatStages = @(
    # (1) 720p, H.264 video and AAC audio
    'bv[height=720][vcodec^=avc1][protocol=https]+ba[acodec^=mp4a][format_id!$=-drc]/bv[height=720][vcodec^=avc1]+ba[acodec^=mp4a]/b[height=720][vcodec^=avc1][acodec^=mp4a]',
    # (2) the best H.264 video up to 1080p
    'bv[height<=1080][vcodec^=avc1][protocol=https]+ba[acodec^=mp4a][format_id!$=-drc]/bv[height<=1080][vcodec^=avc1]+ba[acodec^=mp4a]/bv[height<=1080][vcodec^=avc1]+ba/b[height<=1080][vcodec^=avc1]',
    # (3) the best quality available, put into an MP4 file
    'bv*+ba/b'
)

$script:ToolUrls = @{
    YtDlp  = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
    FFmpeg = 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip'
    Deno   = 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip'
}

# ---------------------------------------------------------------------------
# Settings. Ruth never changes these; the EASYYT_* variables exist for tests.
# ---------------------------------------------------------------------------
function Get-Setting {
    param([string]$Name, $Default)
    $value = [Environment]::GetEnvironmentVariable("EASYYT_$Name")
    if ([string]::IsNullOrEmpty($value)) { return $Default }
    return $value
}

function Get-AppPaths {
    $root = Get-Setting 'HOME' (Join-Path $env:LOCALAPPDATA 'easy-yt2mp4')
    $bin = Join-Path $root 'bin'
    $videos = Get-Setting 'VIDEOS' ([Environment]::GetFolderPath('MyVideos'))
    return @{
        Root    = $root
        Bin     = $bin
        Work    = Join-Path $root 'work'
        Logs    = Join-Path $root 'logs'
        Cache   = Join-Path $root 'cache'
        Videos  = $videos
        YtDlp   = Join-Path $bin 'yt-dlp.exe'
        FFmpeg  = Join-Path $bin 'ffmpeg.exe'
        FFprobe = Join-Path $bin 'ffprobe.exe'
        Deno    = Join-Path $bin 'deno.exe'
    }
}

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------
$script:LogFile = $null

function Write-Log {
    param([string]$Text)
    if (-not $script:LogFile) { return }
    try {
        $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Text
        [System.IO.File]::AppendAllText($script:LogFile, $line + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
    } catch { }
}

function Initialize-Log {
    param([hashtable]$Paths)
    New-Item -ItemType Directory -Force -Path $Paths.Logs | Out-Null
    $script:LogFile = Join-Path $Paths.Logs 'app.log'
    if ((Test-Path -LiteralPath $script:LogFile) -and (Get-Item -LiteralPath $script:LogFile).Length -gt 2MB) {
        Move-Item -LiteralPath $script:LogFile -Destination ($script:LogFile + '.old') -Force
    }
}

# Joins arguments into one Windows command line, quoting as the C runtime expects.
function ConvertTo-ArgumentString {
    param([string[]]$Arguments)
    $parts = foreach ($a in $Arguments) {
        if ($a -eq '') { '""' }
        elseif ($a -notmatch '[\s"]') { $a }
        else {
            $escaped = $a -replace '(\\*)"', '$1$1\"'
            $escaped = $escaped -replace '(\\+)$', '$1$1'
            '"' + $escaped + '"'
        }
    }
    return ($parts -join ' ')
}

function Get-FreeBytes {
    param([string]$Path)
    try {
        $full = [System.IO.Path]::GetFullPath($Path)
        $drive = New-Object System.IO.DriveInfo ([System.IO.Path]::GetPathRoot($full))
        return [long]$drive.AvailableFreeSpace
    } catch {
        return [long]::MaxValue
    }
}

# True when at least one host answers on port 443 within the timeout.
function Test-Internet {
    param([string[]]$HostNames, [int]$TimeoutMs = 2000)
    if (-not $HostNames) {
        $HostNames = (Get-Setting 'PROBE_HOSTS' 'www.youtube.com') -split ','
    }
    foreach ($name in $HostNames) {
        $client = $null
        try {
            $dns = [System.Net.Dns]::BeginGetHostAddresses($name, $null, $null)
            if (-not $dns.AsyncWaitHandle.WaitOne($TimeoutMs)) { continue }
            $addresses = [System.Net.Dns]::EndGetHostAddresses($dns)
            $address = $addresses | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
            if (-not $address) { $address = $addresses | Select-Object -First 1 }
            if (-not $address) { continue }
            $client = New-Object System.Net.Sockets.TcpClient ($address.AddressFamily)
            $connect = $client.BeginConnect($address, 443, $null, $null)
            if ($connect.AsyncWaitHandle.WaitOne($TimeoutMs) -and $client.Connected) { return $true }
        } catch {
        } finally {
            if ($client) { $client.Close() }
        }
    }
    return $false
}

function Stop-ProcessTree {
    param([System.Diagnostics.Process]$Process)
    try {
        if (-not $Process.HasExited) {
            & "$env:SystemRoot\System32\taskkill.exe" /PID $Process.Id /T /F 2>&1 | Out-Null
        }
        [void]$Process.WaitForExit(5000)
    } catch { }
}

# Reads text appended to a file since the last call. Returns complete lines only.
function Read-NewLines {
    param([string]$Path, [hashtable]$State)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    try {
        $stream = New-Object System.IO.FileStream ($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            if ($stream.Length -le $State.Position) { return @() }
            [void]$stream.Seek($State.Position, [System.IO.SeekOrigin]::Begin)
            $buffer = New-Object byte[] ($stream.Length - $State.Position)
            $read = $stream.Read($buffer, 0, $buffer.Length)
            $State.Position += $read
        } finally { $stream.Close() }
        $text = $State.Rest + [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read)
        $lines = $text -split "`r?`n"
        $State.Rest = $lines[-1]
        if ($lines.Count -le 1) { return @() }
        return $lines[0..($lines.Count - 2)]
    } catch {
        return @()
    }
}

# Runs a program hidden, waits up to $TimeoutSeconds, returns its exit code (or -1).
function Invoke-Quiet {
    param([string]$FilePath, [string[]]$Arguments, [int]$TimeoutSeconds = 120, [string]$LogName = 'tool')
    $paths = Get-AppPaths
    $out = Join-Path $paths.Logs "$LogName.out.txt"
    $err = Join-Path $paths.Logs "$LogName.err.txt"
    $p = Start-Process -FilePath $FilePath -ArgumentList (ConvertTo-ArgumentString $Arguments) -NoNewWindow -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err
    $null = $p.Handle
    if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-ProcessTree $p
        Write-Log "$LogName timed out after $TimeoutSeconds s"
        return -1
    }
    $p.WaitForExit()
    return $p.ExitCode
}

# ---------------------------------------------------------------------------
# Links, names and messages
# ---------------------------------------------------------------------------

# Returns the canonical watch URL for a YouTube video link, or $null.
function Get-YouTubeVideoUrl {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $candidates = [regex]::Matches($Text, '[^\s"''<>]+') | ForEach-Object { $_.Value }
    foreach ($candidate in $candidates) {
        $c = $candidate.Trim().TrimEnd('.', ',', ')', ']')
        if ($c -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') { $c = 'https://' + $c }
        $uri = $null
        if (-not [System.Uri]::TryCreate($c, [System.UriKind]::Absolute, [ref]$uri)) { continue }
        if ($uri.Scheme -ne 'http' -and $uri.Scheme -ne 'https') { continue }
        $hostName = $uri.Host.ToLowerInvariant() -replace '^(www|m|music)\.', ''
        $id = $null
        $segments = @($uri.AbsolutePath.Trim('/') -split '/' | Where-Object { $_ -ne '' })
        if ($hostName -eq 'youtu.be') {
            if ($segments.Count -ge 1) { $id = $segments[0] }
        } elseif ($hostName -eq 'youtube.com' -or $hostName -eq 'youtube-nocookie.com') {
            if ($segments.Count -ge 1 -and $segments[0] -eq 'watch') {
                foreach ($pair in $uri.Query.TrimStart('?') -split '&') {
                    $kv = $pair -split '=', 2
                    if ($kv[0] -eq 'v' -and $kv.Count -eq 2) { $id = [System.Uri]::UnescapeDataString($kv[1]); break }
                }
            } elseif ($segments.Count -ge 2 -and @('shorts', 'live', 'embed', 'v', 'e') -contains $segments[0]) {
                $id = $segments[1]
            }
        }
        if ($id -and $id -match '^[A-Za-z0-9_-]{11}$') {
            return "https://www.youtube.com/watch?v=$id"
        }
    }
    return $null
}

# Turns a video title into a safe Windows file name (without extension).
function Get-SafeFileName {
    param([string]$Title, [int]$MaxLength = 120)
    $name = if ($Title) { $Title } else { '' }
    $name = $name -replace '[\x00-\x1f]', ' '
    $name = $name -replace ':', ' -'
    $name = $name -replace '[<>"/\\|?*]', ' '
    $name = ($name -replace '\s+', ' ').Trim().TrimEnd('.').Trim()
    if ($name.Length -gt $MaxLength) {
        $cut = $MaxLength
        if ([char]::IsHighSurrogate($name[$cut - 1])) { $cut-- }
        $name = $name.Substring(0, $cut).Trim().TrimEnd('.').Trim()
    }
    if ($name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$') { $name = "$name video" }
    if ($name -eq '') { $name = 'YouTube video' }
    return $name
}

# "Lecture.mp4", or "Lecture (2).mp4", "Lecture (3).mp4"... if taken.
function Get-UniqueVideoPath {
    param([string]$Folder, [string]$BaseName)
    $path = Join-Path $Folder "$BaseName.mp4"
    $n = 2
    while (Test-Path -LiteralPath $path) {
        $path = Join-Path $Folder ("{0} ({1}).mp4" -f $BaseName, $n)
        $n++
    }
    return $path
}

# Reads yt-dlp's error output and says what kind of failure it was.
function Get-FailureKind {
    param([string]$Log)
    if (-not $Log) { return 'Unknown' }
    if ($Log -match "(?i)not a bot|HTTP Error 429|Too Many Requests") { return 'Bot' }
    if ($Log -match '(?i)No space left|Errno 28|not enough space on the disk|WinError 112|disk is full') { return 'NoSpace' }
    if ($Log -match '(?i)private video|video is private|video is unavailable|video unavailable|has been removed|no longer available|not available in your country|not made this video available|account associated with this video has been terminated|members-only|join this channel|confirm your age|age-restricted|inappropriate for some users|copyright claim|premieres in|live event will begin') { return 'Unavailable' }
    if ($Log -match '(?i)Requested format is not available|No video formats found') { return 'FormatMissing' }
    if ($Log -match '(?i)HTTP Error 403|Forbidden') { return 'Forbidden' }
    if ($Log -match '(?i)getaddrinfo failed|Failed to resolve|Name or service not known|Unable to connect|Connection refused|timed out|Connection reset|Connection aborted|RemoteDisconnected|IncompleteRead|Network is unreachable|WinError 100(51|53|54|60|65)|WinError 11001') { return 'Network' }
    if ($Log -match '(?i)Postprocessing|Merger|ffmpeg|Conversion failed|ffprobe') { return 'Merge' }
    return 'Unknown'
}

# What Ruth is told when every quality stage failed for this last reason.
function Get-FinalOutcome {
    param([string]$LastKind)
    switch ($LastKind) {
        'Bot'           { return 'Blocked' }
        'Forbidden'     { return 'Blocked' }
        'Unavailable'   { return 'Unavailable' }
        'NoSpace'       { return 'NoSpace' }
        'NoInternet'    { return 'NoInternet' }
        'Merge'         { return 'NoPictureSound' }
        'NoAV'          { return 'NoPictureSound' }
        'FormatMissing' { return 'NoPictureSound' }
        default         { return 'Other' }
    }
}

# Kinds where trying a lower quality will not help.
function Test-StopsAllStages {
    param([string]$Kind)
    return @('Bot', 'Unavailable', 'NoSpace', 'NoInternet') -contains $Kind
}

# One number for the whole save: picture is about 90% of the bytes, sound 10%.
function Get-OverallPercent {
    param([string]$VCodec, [string]$ACodec, [double]$Percent)
    $hasVideo = $VCodec -and $VCodec -ne 'none'
    $hasAudio = $ACodec -and $ACodec -ne 'none'
    if ($hasVideo -and -not $hasAudio) { $value = $Percent * 0.9 }
    elseif ($hasAudio -and -not $hasVideo) { $value = 90 + $Percent * 0.1 }
    else { $value = $Percent }
    return [int][Math]::Floor([Math]::Min(99, [Math]::Max(0, $value)))
}

# ---------------------------------------------------------------------------
# Screen
# ---------------------------------------------------------------------------
function Write-Say {
    param([string]$Text, [string]$Color = '')
    if ($script:ProgressShown) { Write-Host ''; $script:ProgressShown = $false }
    Write-Host ''
    if ($Color) { Write-Host "  $Text" -ForegroundColor $Color } else { Write-Host "  $Text" }
}

$script:ProgressShown = $false
function Write-ProgressLine {
    param([string]$Text)
    Write-Host -NoNewline ("`r  {0,-40}" -f $Text)
    $script:ProgressShown = $true
}

function Test-NoWait { return (Get-Setting 'NO_WAIT' '') -eq '1' }

# Keeps the window open until Ruth closes it.
function Wait-UntilClosed {
    if (Test-NoWait) { return }
    while ($true) {
        try { [void][Console]::ReadKey($true) } catch { Start-Sleep -Seconds 1 }
    }
}

# ---------------------------------------------------------------------------
# Setup and updates
# ---------------------------------------------------------------------------
function Get-MissingTools {
    param([hashtable]$Paths)
    $missing = @()
    if (-not (Test-Path -LiteralPath $Paths.YtDlp)) { $missing += 'YtDlp' }
    if (-not ((Test-Path -LiteralPath $Paths.FFmpeg) -and (Test-Path -LiteralPath $Paths.FFprobe))) { $missing += 'FFmpeg' }
    if (-not (Test-Path -LiteralPath $Paths.Deno)) { $missing += 'Deno' }
    return $missing
}

function Save-Url {
    param([string]$Url, [string]$Destination)
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (Test-Path -LiteralPath $curl) {
        $code = Invoke-Quiet -FilePath $curl -Arguments @('-sSL', '--fail', '--retry', '2', '--connect-timeout', '20', '-o', $Destination, $Url) -TimeoutSeconds 1800 -LogName 'setup-download'
        if ($code -eq 0 -and (Test-Path -LiteralPath $Destination)) { return }
        throw "curl failed with $code for $Url"
    }
    $client = New-Object System.Net.WebClient
    try { $client.DownloadFile($Url, $Destination) } finally { $client.Dispose() }
}

function Expand-Zip {
    param([string]$Zip, [string]$Destination)
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (Test-Path -LiteralPath $tar) {
        $code = Invoke-Quiet -FilePath $tar -Arguments @('-xf', $Zip, '-C', $Destination) -TimeoutSeconds 600 -LogName 'setup-extract'
        if ($code -eq 0) { return }
    }
    Expand-Archive -LiteralPath $Zip -DestinationPath $Destination -Force
}

function Install-Tool {
    param([hashtable]$Paths, [string]$Tool)
    $url = Get-Setting ('URL_' + $Tool.ToUpperInvariant()) $script:ToolUrls[$Tool]
    $temp = Join-Path $Paths.Work ('setup-' + $Tool)
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    try {
        Write-Log "Setting up $Tool from $url"
        if ($Tool -eq 'YtDlp') {
            $file = Join-Path $temp 'yt-dlp.exe'
            Save-Url $url $file
            Copy-Item -LiteralPath $file -Destination $Paths.YtDlp -Force
            return
        }
        $zip = Join-Path $temp 'download.zip'
        Save-Url $url $zip
        $unpacked = Join-Path $temp 'unpacked'
        Expand-Zip $zip $unpacked
        if ($Tool -eq 'Deno') {
            $exe = Get-ChildItem -LiteralPath $unpacked -Recurse -Filter 'deno.exe' | Select-Object -First 1
            if (-not $exe) { throw 'deno.exe not found in download' }
            Copy-Item -LiteralPath $exe.FullName -Destination $Paths.Deno -Force
        } else {
            $exe = Get-ChildItem -LiteralPath $unpacked -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1
            if (-not $exe) { throw 'ffmpeg.exe not found in download' }
            Get-ChildItem -LiteralPath $exe.DirectoryName | Where-Object { $_.Name -ne 'ffplay.exe' } |
                Copy-Item -Destination $Paths.Bin -Force
        }
    } finally {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Sets up whatever is missing, otherwise checks for a yt-dlp update.
# Returns 'Ok', 'SetupNoNet' or 'SetupOther'.
function Initialize-Tools {
    param([hashtable]$Paths)
    foreach ($dir in @($Paths.Bin, $Paths.Work, $Paths.Cache)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $missing = @(Get-MissingTools $Paths)
    if ($missing.Count -eq 0) {
        $code = Invoke-Quiet -FilePath $Paths.YtDlp -Arguments @('-U') -TimeoutSeconds 90 -LogName 'update'
        Write-Log "yt-dlp update check finished with $code"
        return 'Ok'
    }
    try {
        foreach ($tool in $missing) { Install-Tool $Paths $tool }
        $still = @(Get-MissingTools $Paths)
        if ($still.Count -gt 0) { throw "still missing: $($still -join ', ')" }
        $code = Invoke-Quiet -FilePath $Paths.YtDlp -Arguments @('--version') -TimeoutSeconds 60 -LogName 'version'
        if ($code -ne 0) { throw "yt-dlp does not run ($code)" }
        Write-Log 'Setup finished'
        return 'Ok'
    } catch {
        Write-Log "Setup failed: $_"
        $hosts = (Get-Setting 'PROBE_HOSTS' 'github.com,www.youtube.com') -split ','
        if (-not (Test-Internet -HostNames $hosts -TimeoutMs 4000)) { return 'SetupNoNet' }
        return 'SetupOther'
    }
}

# ---------------------------------------------------------------------------
# Saving
# ---------------------------------------------------------------------------

# Returns the stream types in a file, e.g. @('video', 'audio'). Cover images are skipped.
function Get-StreamTypes {
    param([hashtable]$Paths, [string]$File)
    $ErrorActionPreference = 'Continue'
    $lines = & $Paths.FFprobe -v error -show_entries 'stream=codec_type:stream_disposition=attached_pic' -of 'csv=p=0' $File 2>$null
    $types = @()
    foreach ($line in @($lines)) {
        $f = "$line".Trim() -split ','
        if ($f[0] -eq 'video' -and $f.Count -ge 2 -and $f[1] -eq '1') { continue }
        if ($f[0]) { $types += $f[0] }
    }
    return $types
}

# One yt-dlp run for one quality stage. Returns @{ Ok; Kind; File; Title }.
function Invoke-SaveAttempt {
    param([hashtable]$Paths, [string]$Url, [string]$Format, [string]$WorkDir, [hashtable]$Clock)
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    $out = Join-Path $WorkDir 'yt-dlp.out.txt'
    $err = Join-Path $WorkDir 'yt-dlp.err.txt'
    $titleFile = Join-Path $WorkDir 'title.txt'
    $arguments = @(
        '--ignore-config', '--no-playlist', '--newline', '--no-colors', '--no-mtime',
        '--socket-timeout', '20', '--retries', '5', '--fragment-retries', '5',
        '--cache-dir', $Paths.Cache,
        '--ffmpeg-location', $Paths.Bin,
        '--js-runtimes', ('deno:' + $Paths.Deno),
        '-f', $Format,
        '--merge-output-format', 'mp4', '--remux-video', 'mp4',
        '--progress-template', 'download:EYTP %(info.vcodec)s|%(info.acodec)s|%(progress._percent_str)s',
        '--print-to-file', '%(title)s', $titleFile,
        '-o', (Join-Path $WorkDir 'video.%(ext)s'),
        $Url
    )
    Write-Log "yt-dlp -f $Format $Url"
    $p = Start-Process -FilePath $Paths.YtDlp -ArgumentList (ConvertTo-ArgumentString $arguments) -NoNewWindow -PassThru `
        -RedirectStandardOutput $out -RedirectStandardError $err
    $null = $p.Handle

    $state = @{ Position = 0; Rest = '' }
    $best = -1
    $netFails = 0
    $lastCheck = Get-Date
    $longAfter = [int](Get-Setting 'LONG_SECONDS' '600')
    $killedFor = $null

    while (-not $p.WaitForExit(400)) {
        foreach ($line in (Read-NewLines $out $state)) {
            if ($line -match '^EYTP ([^|]*)\|([^|]*)\|\s*([\d.]+)%') {
                $pct = Get-OverallPercent $Matches[1] $Matches[2] ([double]$Matches[3])
                if ($pct -gt $best) { $best = $pct; Write-ProgressLine ("Saved so far: {0}%" -f $pct) }
            } elseif ($line -match '^\[(Merger|VideoRemuxer|FixupM3u8|FixupM4a)\]') {
                Write-ProgressLine 'Almost done...'
            }
        }
        if (-not $Clock.LongShown -and ((Get-Date) - $Clock.Start).TotalSeconds -ge $longAfter) {
            $Clock.LongShown = $true
            Write-Say $script:Messages.TakingLong
        }
        if (((Get-Date) - $lastCheck).TotalMilliseconds -ge 1500) {
            $lastCheck = Get-Date
            if (Test-Internet) { $netFails = 0 } else { $netFails++ }
            if ($netFails -ge 2) { $killedFor = 'NoInternet'; break }
            if ((Get-FreeBytes $WorkDir) -lt 100MB) { $killedFor = 'NoSpace'; break }
        }
    }
    if ($killedFor) {
        Stop-ProcessTree $p
        Write-Log "Stopped yt-dlp: $killedFor"
        return @{ Ok = $false; Kind = $killedFor }
    }
    $p.WaitForExit()
    $exit = $p.ExitCode
    $errText = ''
    if (Test-Path -LiteralPath $err) { $errText = [System.IO.File]::ReadAllText($err, [System.Text.Encoding]::UTF8) }
    Write-Log "yt-dlp exit $exit"
    if ($errText) { Write-Log ("yt-dlp said: " + ($errText.Trim() -replace '\s*\r?\n\s*', ' | ')) }

    $file = Join-Path $WorkDir 'video.mp4'
    if ($exit -ne 0 -or -not (Test-Path -LiteralPath $file)) {
        return @{ Ok = $false; Kind = (Get-FailureKind $errText) }
    }
    $title = ''
    if (Test-Path -LiteralPath $titleFile) {
        $title = ([System.IO.File]::ReadAllText($titleFile, [System.Text.Encoding]::UTF8) -split "`r?`n")[0]
    }
    return @{ Ok = $true; File = $file; Title = $title }
}

# Saves one video. Returns an outcome name and, when saved, the file path.
function Save-Video {
    param([hashtable]$Paths, [string]$Text)
    $url = Get-YouTubeVideoUrl $Text
    if (-not $url) { return @{ Outcome = 'NotALink' } }

    Write-Say $script:Messages.Started
    $clock = @{ Start = Get-Date; LongShown = $false }

    if (-not (Test-Internet)) { return @{ Outcome = 'NoInternet' } }
    if ((Get-FreeBytes $Paths.Work) -lt 200MB -or (Get-FreeBytes $Paths.Videos) -lt 200MB) { return @{ Outcome = 'NoSpace' } }

    $env:PATH = $Paths.Bin + ';' + $env:PATH
    $lastKind = 'Unknown'
    $stage = 0
    foreach ($format in $script:FormatStages) {
        $stage++
        $work = Join-Path $Paths.Work ([guid]::NewGuid().ToString('N'))
        try {
            $attempt = Invoke-SaveAttempt -Paths $Paths -Url $url -Format $format -WorkDir $work -Clock $clock
            if ($attempt.Ok) {
                $types = @(Get-StreamTypes $Paths $attempt.File)
                Write-Log "Stage $stage saved streams: $($types -join ',')"
                if (($types -contains 'video') -and ($types -contains 'audio')) {
                    $base = Get-SafeFileName $attempt.Title ([Math]::Max(40, [Math]::Min(120, 240 - $Paths.Videos.Length)))
                    $target = Get-UniqueVideoPath $Paths.Videos $base
                    try {
                        Move-Item -LiteralPath $attempt.File -Destination $target
                    } catch {
                        Write-Log "Move failed: $_"
                        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue }
                        if ((Get-FreeBytes $Paths.Videos) -lt 200MB) { return @{ Outcome = 'NoSpace' } }
                        return @{ Outcome = 'Other' }
                    }
                    Write-Log "Saved $target"
                    return @{ Outcome = 'Saved'; File = $target }
                }
                $lastKind = 'NoAV'
                continue
            }
            $kind = $attempt.Kind
            if (@('Network', 'Unknown', 'Merge') -contains $kind -and -not (Test-Internet)) { $kind = 'NoInternet' }
            if ((Get-FreeBytes $work) -lt 200MB) { $kind = 'NoSpace' }
            Write-Log "Stage $stage failed: $kind"
            $lastKind = $kind
            if (Test-StopsAllStages $kind) { break }
        } finally {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    return @{ Outcome = (Get-FinalOutcome $lastKind) }
}

function Show-SavedFile {
    param([string]$File)
    if ((Get-Setting 'NO_EXPLORER' '') -eq '1') { return }
    Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList ('/select,"{0}"' -f $File)
}

# ---------------------------------------------------------------------------
# The app
# ---------------------------------------------------------------------------
function Start-App {
    param([string]$Url)
    $paths = Get-AppPaths
    Initialize-Log $paths
    Write-Log "App started (version $(Get-AppVersion))"
    try { $Host.UI.RawUI.WindowTitle = 'Save YouTube Video' } catch { }

    Write-Say $script:Messages.Updating
    $setup = Initialize-Tools $paths
    if ($setup -ne 'Ok') {
        Write-Say $script:Messages[$setup] 'Yellow'
        Wait-UntilClosed
        return $script:Outcomes[$setup].Code
    }
    Get-ChildItem -LiteralPath $paths.Work -Directory -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    while ($true) {
        if ($Url) {
            $text = $Url
            $Url = $null
        } else {
            if (Test-NoWait) { return $script:Outcomes.NotALink.Code }
            Write-Say $script:Messages.AskLink
            Write-Host "  $($script:Messages.PasteHint)"
            Write-Host ''
            Write-Host -NoNewline '  > '
            $text = [Console]::ReadLine()
        }
        $result = Save-Video $paths $text
        $outcome = $result.Outcome
        Write-Log "Outcome: $outcome"
        if ($outcome -eq 'Saved') {
            Write-Say $script:Messages.Done 'Green'
            Show-SavedFile $result.File
            if (-not (Test-NoWait)) { Start-Sleep -Seconds 3 }
            return 0
        }
        Write-Say $script:Messages[$outcome] 'Yellow'
        if (Test-NoWait) { return $script:Outcomes[$outcome].Code }
        if (-not $script:Outcomes[$outcome].AskAgain) {
            Wait-UntilClosed
            return $script:Outcomes[$outcome].Code
        }
    }
}

function Get-AppVersion {
    $file = Join-Path $PSScriptRoot 'VERSION'
    if (Test-Path -LiteralPath $file) { return (Get-Content -LiteralPath $file -TotalCount 1).Trim() }
    return 'dev'
}
