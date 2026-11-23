# Architecture

The whole app is two PowerShell 5.1 scripts that drive three portable tools. There is no server, no build
step and no installed runtime beyond what ships with Windows 11.

## What runs where

```
GitHub (public repo eldarab/easy-yt2mp4)
 |-- main/install.ps1  -------------------- fetched by:  irm .../install.ps1 | iex
 `-- releases/latest/download/easy-yt2mp4.zip  (built by .github/workflows/release.yml on a v*.*.* tag)

Ruth's PC
 Desktop\Save YouTube Video.lnk
   -> powershell.exe -NoProfile -ExecutionPolicy Bypass -File %LOCALAPPDATA%\easy-yt2mp4\app\SaveYouTubeVideo.ps1

 %LOCALAPPDATA%\easy-yt2mp4\
   app\    SaveYouTubeVideo.ps1, EasyYt2Mp4.ps1, icon.ico, VERSION, LICENSE   (replaced on every install)
   bin\    yt-dlp.exe, ffmpeg.exe, ffprobe.exe, ffmpeg DLLs, deno.exe        (set up by the app on first open)
   work\   one temporary folder per save; emptied at start and after each attempt
   cache\  yt-dlp cache
   logs\   app.log (rotates at 2 MB) and the output of the last setup/update run

 Videos\  <title>.mp4  -- the only thing the app ever writes here, and only once a save is complete
```

## The app, step by step

`SaveYouTubeVideo.ps1` dot-sources `EasyYt2Mp4.ps1` and calls `Start-App`. Any unexpected exception ends in the
"Something went wrong" message, so Ruth never sees a PowerShell error.

1. **Updating** (`Initialize-Tools`). Shows "The app is updating. Please wait a moment." If any tool is
   missing, downloads it (curl.exe, then tar.exe to unzip). Otherwise runs `yt-dlp -U` with a 90 s limit and
   ignores the result. A failed setup checks the internet to choose between the two setup messages.
2. **Ask for the link.** Reads one line from the console.
3. **Check the link** (`Get-YouTubeVideoUrl`). Pulls the 11-character video id out of any YouTube link form
   (watch, youtu.be, shorts, live, embed, m./music.) and rebuilds a clean watch URL, dropping playlists.
   Anything else gets the not-a-link message and the question again.
4. **Pre-checks.** Prints "Saving the video..." at once (the 1-second rule), then checks the internet and
   that both the work and Videos drives have 200 MB free.
5. **Quality stages** (`$FormatStages`, `Save-Video`). Up to three yt-dlp runs, one per stage of the ticket's
   quality order. Each run saves into its own `work\<guid>` folder as `video.mp4` (merge and remux only,
   never re-encode) and writes the title to `title.txt`.
6. **While yt-dlp runs** (`Invoke-SaveAttempt`). Every 400 ms: read new progress lines and show
   "Saved so far: N%" (picture counts as 90%, sound 10%). Every 1.5 s: probe www.youtube.com:443 and check
   free space; two failed probes in a row or under 100 MB free stops yt-dlp, so a dropped connection is
   reported within about 7 s. After 10 minutes, show the taking-longer message once and carry on.
7. **Decide.** On success, ffprobe must find both a video stream (not a cover image) and an audio stream,
   else that stage counts as failed. On failure, `Get-FailureKind` reads yt-dlp's error text. Some kinds
   stop at once (bot check, unavailable, no space, no internet); others try the next stage. When stages run
   out, `Get-FinalOutcome` maps the last kind to one of the approved messages.
8. **Deliver.** Picks `<safe title>.mp4` or `<safe title> (N).mp4`, moves the file into Videos, opens
   Explorer with it selected, says "Done!" and closes after 3 seconds.

After a failure, the app asks for the link again when the message tells Ruth to check something and try
again; when the message tells her to close and reopen the app, it just waits until she closes the window.

## Failure kinds

| Kind (from yt-dlp text or a probe) | Tries the next quality? | Message Ruth sees |
| --- | --- | --- |
| Bot (`not a bot`, HTTP 429) | No | Blocked |
| Unavailable (private, removed, age-gated, members-only, region) | No | Unavailable |
| NoSpace (`No space left`, WinError 112, or < 100/200 MB free) | No | NoSpace |
| NoInternet (two failed probes) | No | NoInternet |
| FormatMissing (`Requested format is not available`) | Yes | NoPictureSound if last |
| Forbidden (HTTP 403) | Yes | Blocked if last |
| Merge (ffmpeg / postprocessing) or NoAV (ffprobe check) | Yes | NoPictureSound if last |
| Network with the internet still up, or Unknown | Yes | Other if last |

## Where each ticket scenario is tested

| US-001 scenario | Automated | Manual checklist |
| --- | --- | --- |
| Install with one command | Integration: install.ps1 | Install |
| First-time setup by itself | Integration: first-time setup | First run |
| Updates itself / already up to date | Integration: yt-dlp update | First run |
| Update cannot be completed | (not automated; the update result is ignored by design) | |
| First-time setup cannot be completed (both rows) | Integration: two setup-failure tests | Optional row |
| Saving has started within 1 s | Integration checks the message; timing by eye | Saving |
| Saves a lecture, Explorer highlights it, app closes | Integration (file); Explorer by hand | Saving |
| Same name exists | Integration: same name | Saving |
| Motion and sound, MP4, plays | Integration: ffprobe checks | Saving |
| 720p without choosing | Integration: Big Buck Bunny | Saving |
| Falls back to best quality | Integration: "Me at the zoo" (240p only) | |
| Failure messages | Unit (wording, classification); integration (not a link, removed, offline) | When saving fails |
| Taking longer than usual | Integration with `EASYYT_LONG_SECONDS=1` | Long lecture |
