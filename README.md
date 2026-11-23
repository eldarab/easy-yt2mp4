# Save YouTube Video

Paste a YouTube link, and the video is saved to the Windows **Videos** folder as an MP4 file.

## Install (Windows 11)

1. Open **PowerShell** (press the Windows key, type `PowerShell`, press Enter).
2. Paste this line and press Enter:

```powershell
irm https://raw.githubusercontent.com/eldarab/easy-yt2mp4/main/install.ps1 | iex
```

A **Save YouTube Video** icon appears on the desktop. No admin rights are needed.

## Use

1. Copy the link of a YouTube video.
2. Double-click **Save YouTube Video** on the desktop.
3. Paste the link (Ctrl+V or right-click) and press Enter.

When it's done, the Videos folder opens with the new video selected. The first time, the app takes a minute or two to get ready.

---

More: [manual test checklist](docs/manual-test-checklist.md) · [development](docs/development.md) · [changelog](CHANGELOG.md) · uninstall with
`irm https://raw.githubusercontent.com/eldarab/easy-yt2mp4/main/uninstall.ps1 | iex`

Built on [yt-dlp](https://github.com/yt-dlp/yt-dlp) (Unlicense), [FFmpeg](https://ffmpeg.org) (GPL, [yt-dlp builds](https://github.com/yt-dlp/FFmpeg-Builds)) and [Deno](https://deno.com) (MIT), which the app downloads on first run. MIT licensed.
