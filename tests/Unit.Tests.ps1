# Unit tests for the app's functions. No network, no downloads.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\Unit.Tests.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')
. (Join-Path $PSScriptRoot '..\src\EasyYt2Mp4.ps1')

Describe 'Get-YouTubeVideoUrl accepts video links' {
    $expected = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
    foreach ($link in @(
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            'http://youtube.com/watch?v=dQw4w9WgXcQ',
            'www.youtube.com/watch?v=dQw4w9WgXcQ',
            'youtube.com/watch?v=dQw4w9WgXcQ',
            'https://m.youtube.com/watch?v=dQw4w9WgXcQ&feature=share',
            'https://www.youtube.com/watch?feature=shared&v=dQw4w9WgXcQ&t=42s',
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL1234567890&index=3',
            'https://youtu.be/dQw4w9WgXcQ',
            'https://youtu.be/dQw4w9WgXcQ?si=abcDEF123&t=10',
            'https://www.youtube.com/shorts/dQw4w9WgXcQ',
            'https://www.youtube.com/live/dQw4w9WgXcQ?si=x',
            'https://www.youtube.com/embed/dQw4w9WgXcQ',
            'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
            '  https://youtu.be/dQw4w9WgXcQ  ',
            '"https://youtu.be/dQw4w9WgXcQ"',
            'Look at this: https://youtu.be/dQw4w9WgXcQ.',
            'HTTPS://WWW.YOUTUBE.COM/watch?v=dQw4w9WgXcQ'
        )) {
        Assert-Equal $expected (Get-YouTubeVideoUrl $link) "link: $link"
    }
}

Describe 'Get-YouTubeVideoUrl rejects everything else' {
    foreach ($text in @(
            '', '   ', $null, 'hello', 'Lecture about history',
            'https://www.google.com/watch?v=dQw4w9WgXcQ',
            'https://vimeo.com/123456789',
            'https://www.youtube.com/',
            'https://www.youtube.com/playlist?list=PL1234567890',
            'https://www.youtube.com/@SomeChannel',
            'https://www.youtube.com/watch?v=short',
            'https://notyoutube.com/watch?v=dQw4w9WgXcQ',
            'ftp://youtube.com/watch?v=dQw4w9WgXcQ',
            'C:\Users\Ruth\Videos\Lecture.mp4'
        )) {
        Assert-Equal $null (Get-YouTubeVideoUrl $text) "text: '$text'"
    }
}

Describe 'Get-SafeFileName' {
    Assert-Equal 'Lecture' (Get-SafeFileName 'Lecture')
    Assert-Equal 'Part 1 - The Beginning' (Get-SafeFileName 'Part 1: The Beginning')
    Assert-Equal 'What is AC DC' (Get-SafeFileName 'What is AC/DC?')
    Assert-Equal 'a b c d e f' (Get-SafeFileName 'a<b>c|d*e"f')
    Assert-Equal 'Ends with dots' (Get-SafeFileName 'Ends with dots...')
    Assert-Equal 'YouTube video' (Get-SafeFileName '')
    Assert-Equal 'YouTube video' (Get-SafeFileName '???')
    Assert-Equal 'CON video' (Get-SafeFileName 'CON')
    Assert-Equal 'tab and newline' (Get-SafeFileName "tab`tand`nnewline")
    $hebrew = [string]([char]0x05E9) + [char]0x05DC + [char]0x05D5 + [char]0x05DD
    Assert-Equal $hebrew (Get-SafeFileName $hebrew) 'keeps non-Latin letters'
    Assert-Equal 50 (Get-SafeFileName ('x' * 300) 50).Length 'cuts long titles'
    $emoji = 'a' * 49 + [char]::ConvertFromUtf32(0x1F600)
    $cut = Get-SafeFileName $emoji 50
    Assert-True (-not [char]::IsHighSurrogate($cut[-1])) 'does not split an emoji'
}

Describe 'Get-UniqueVideoPath' {
    $dir = New-TestFolder
    try {
        Assert-Equal (Join-Path $dir 'Lecture.mp4') (Get-UniqueVideoPath $dir 'Lecture')
        Set-Content -LiteralPath (Join-Path $dir 'Lecture.mp4') -Value 'x'
        Assert-Equal (Join-Path $dir 'Lecture (2).mp4') (Get-UniqueVideoPath $dir 'Lecture')
        Set-Content -LiteralPath (Join-Path $dir 'Lecture (2).mp4') -Value 'x'
        Assert-Equal (Join-Path $dir 'Lecture (3).mp4') (Get-UniqueVideoPath $dir 'Lecture')
        Assert-Equal (Join-Path $dir 'Other [1].mp4') (Get-UniqueVideoPath $dir 'Other [1]') 'brackets are not wildcards'
        Set-Content -LiteralPath (Join-Path $dir 'Other [1].mp4') -Value 'x'
        Assert-Equal (Join-Path $dir 'Other [1] (2).mp4') (Get-UniqueVideoPath $dir 'Other [1]')
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force }
}

Describe 'Get-FailureKind' {
    $cases = @(
        @("ERROR: [youtube] abc: Sign in to confirm you're not a bot. Use --cookies", 'Bot'),
        @('ERROR: unable to download video data: HTTP Error 429: Too Many Requests', 'Bot'),
        @('ERROR: [youtube] aaaaaaaaaaa: This video is unavailable', 'Unavailable'),
        @('ERROR: [youtube] abc: Private video. Sign in if you have been granted access', 'Unavailable'),
        @('ERROR: [youtube] abc: This video has been removed by the uploader', 'Unavailable'),
        @('ERROR: [youtube] abc: Sign in to confirm your age. This video may be inappropriate for some users.', 'Unavailable'),
        @('ERROR: [youtube] abc: Join this channel to get access to members-only content', 'Unavailable'),
        @('ERROR: [youtube] abc: Requested format is not available. Use --list-formats', 'FormatMissing'),
        @('ERROR: unable to download video data: HTTP Error 403: Forbidden', 'Forbidden'),
        @('ERROR: [Errno 28] No space left on device', 'NoSpace'),
        @('ERROR: [WinError 112] There is not enough space on the disk', 'NoSpace'),
        @('ERROR: Unable to download webpage: <urlopen error [Errno 11001] getaddrinfo failed>', 'Network'),
        @('ERROR: [WinError 10054] An existing connection was forcibly closed', 'Network'),
        @('ERROR: Read timed out.', 'Network'),
        @('ERROR: Postprocessing: Conversion failed!', 'Merge'),
        @('ERROR: something we have never seen', 'Unknown'),
        @('', 'Unknown')
    )
    foreach ($c in $cases) { Assert-Equal $c[1] (Get-FailureKind $c[0]) $c[0] }
}

Describe 'Get-FinalOutcome and stopping rules' {
    Assert-Equal 'Blocked' (Get-FinalOutcome 'Bot')
    Assert-Equal 'Blocked' (Get-FinalOutcome 'Forbidden')
    Assert-Equal 'Unavailable' (Get-FinalOutcome 'Unavailable')
    Assert-Equal 'NoSpace' (Get-FinalOutcome 'NoSpace')
    Assert-Equal 'NoInternet' (Get-FinalOutcome 'NoInternet')
    Assert-Equal 'NoPictureSound' (Get-FinalOutcome 'NoAV')
    Assert-Equal 'NoPictureSound' (Get-FinalOutcome 'Merge')
    Assert-Equal 'NoPictureSound' (Get-FinalOutcome 'FormatMissing')
    Assert-Equal 'Other' (Get-FinalOutcome 'Unknown')
    Assert-Equal 'Other' (Get-FinalOutcome 'Network')
    Assert-True (Test-StopsAllStages 'Unavailable') 'unavailable stops'
    Assert-True (Test-StopsAllStages 'Bot') 'bot check stops'
    Assert-True (-not (Test-StopsAllStages 'FormatMissing')) 'missing format tries the next quality'
    Assert-True (-not (Test-StopsAllStages 'Forbidden')) '403 tries the next quality'
    foreach ($o in $script:Outcomes.Keys) {
        if ($o -ne 'Saved') { Assert-True ($script:Messages.ContainsKey($o)) "message exists for $o" }
    }
}

Describe 'Get-OverallPercent' {
    Assert-Equal 0 (Get-OverallPercent 'avc1.4d401f' 'none' 0)
    Assert-Equal 45 (Get-OverallPercent 'avc1.4d401f' 'none' 50)
    Assert-Equal 90 (Get-OverallPercent 'avc1.4d401f' 'none' 100)
    Assert-Equal 95 (Get-OverallPercent 'none' 'mp4a.40.2' 50)
    Assert-Equal 99 (Get-OverallPercent 'none' 'mp4a.40.2' 100)
    Assert-Equal 50 (Get-OverallPercent 'avc1' 'mp4a.40.2' 50)
}

Describe 'ConvertTo-ArgumentString' {
    Assert-Equal 'a b' (ConvertTo-ArgumentString @('a', 'b'))
    Assert-Equal '"two words" x' (ConvertTo-ArgumentString @('two words', 'x'))
    Assert-Equal '""' (ConvertTo-ArgumentString @(''))
    Assert-Equal '"say \"hi\""' (ConvertTo-ArgumentString @('say "hi"'))
    Assert-Equal '"C:\My Dir\\"' (ConvertTo-ArgumentString @('C:\My Dir\'))
    Assert-Equal 'bv*+ba/b' (ConvertTo-ArgumentString @('bv*+ba/b'))
}

Describe 'Quality order' {
    Assert-Equal 3 $script:FormatStages.Count
    Assert-True ($script:FormatStages[0] -match '^bv\[height=720\]\[vcodec\^=avc1\]') 'stage 1 is 720p H.264'
    Assert-True ($script:FormatStages[0] -match 'acodec\^=mp4a') 'stage 1 asks for AAC'
    Assert-True ($script:FormatStages[1] -match 'height<=1080\]\[vcodec\^=avc1\]') 'stage 2 is H.264 up to 1080p'
    Assert-Equal 'bv*+ba/b' $script:FormatStages[2]
}

Describe 'Approved wording' {
    # Guards against accidental edits. Changes go back to the product owner.
    Assert-Equal 'The app is updating. Please wait a moment.' $script:Messages.Updating
    Assert-Equal 'This is not a link to a YouTube video. Please copy the link again from the YouTube page and paste it here.' $script:Messages.NotALink
    Assert-Equal "This video can't be saved because it is private or no longer on YouTube. Please check that you can still watch it on YouTube." $script:Messages.Unavailable
    Assert-Equal 'The internet stopped working, so the video was not saved. Please check that your internet is on, then try again.' $script:Messages.NoInternet
    Assert-Equal "Your computer is too full to save this video. Please delete some files you don't need, or ask someone to help you, then try again." $script:Messages.NoSpace
    Assert-Equal "YouTube isn't letting the app save this video right now. Please close the app, open it again, and try once more. If it still doesn't work, try again tomorrow." $script:Messages.Blocked
    Assert-Equal "The video couldn't be saved with both picture and sound, so nothing was saved. Please close the app, open it again, and try once more." $script:Messages.NoPictureSound
    Assert-Equal 'Something went wrong and the video was not saved. Please close the app, open it again, and try once more. If it happens again, ask someone to help you.' $script:Messages.Other
    Assert-Equal "The app couldn't get ready because the internet isn't working. Please check that your internet is on, then open the app again." $script:Messages.SetupNoNet
    Assert-Equal "The app couldn't get ready. Please close it and open it again. If it happens again, ask someone to help you." $script:Messages.SetupOther
    Assert-Equal 'Saving is taking longer than usual. Please keep this window open and wait a little longer.' $script:Messages.TakingLong
    foreach ($key in $script:Messages.Keys) {
        Assert-True ($script:Messages[$key] -notmatch '(?i)\berror\b|download failed|invalid url') "no technical words in $key"
    }
}

Describe 'Every source file is ASCII (Windows PowerShell 5.1 reads them as ANSI)' {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..') -Recurse -File -Filter *.ps1) {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        Assert-True (-not ($bytes | Where-Object { $_ -gt 127 } | Select-Object -First 1)) "$($file.Name) is ASCII"
    }
}

Complete-Tests
