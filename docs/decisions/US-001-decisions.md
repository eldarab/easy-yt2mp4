# US-001 decisions

Calls made while building [US-001](../specs/US-001-save-youtube-lecture.md) that the ticket did not settle.
The product owner asked for the simplest recommended option whenever there was a choice, without being asked.
Change any of these with a new user story or a pull request that updates this file.

| # | Decision | Alternatives considered | Why |
| --- | --- | --- | --- |
| 1 | Plain Windows PowerShell 5.1 console app, two `.ps1` files | WinForms window with a button; PowerShell 7; a compiled exe | The ticket says the console is acceptable to Ruth. 5.1 ships with every Windows 11, needs no signing and no install. |
| 2 | ffmpeg from yt-dlp's own builds, the *shared* (DLL) variant, 91 MB | Static build (202 MB); gyan.dev builds | Made and tested for yt-dlp; half the download. GPL is fine: it is downloaded at runtime, not redistributed. |
| 3 | Tools are downloaded by the app on first open, not by the installer | Installer pre-downloads them | The ticket's "First-time setup happens by itself when the app opens" scenario. Keeps the installer tiny and fast. |
| 4 | The installer downloads a release zip (`releases/latest/download/easy-yt2mp4.zip`) | Copy raw files from `main` | Users only get tagged, CI-tested releases; `main` can move without affecting them. No GitHub API call, so no rate limit. |
| 5 | Each quality stage is a separate yt-dlp run | One format string with `/` fallbacks | The ticket says fall back when 720p "is not available **or fails**". A single run only falls back when a format is missing. |
| 6 | Inside a stage, prefer plain HTTPS (DASH) formats over HLS (m3u8), and non-DRC audio | Let yt-dlp choose | HTTPS formats download faster and more reliably; DRC audio is a compressed-loudness variant. |
| 7 | `--merge-output-format mp4 --remux-video mp4` | Allow mkv/webm when stage 3 picks VP9/Opus | The ticket requires MP4 and no re-encoding; remuxing VP9/AV1/Opus into MP4 is lossless and VLC plays it. |
| 8 | Save into `%LOCALAPPDATA%\easy-yt2mp4\work`, then move into Videos | Save straight into Videos with `.part` files | Guarantees "no file or partial file is left in the Videos folder", even if the window is closed mid-save. |
| 9 | Check every result with ffprobe for a video and an audio stream | Trust yt-dlp | The "motion and sound" scenario; catches a bad merge before Ruth sees a silent file. |
| 10 | A watchdog probes `www.youtube.com:443` every 1.5 s during a save and stops yt-dlp after two failures | Rely on yt-dlp's timeouts | yt-dlp retries for minutes; the ticket needs the message "within 10 seconds of the problem". |
| 11 | Free-space thresholds: 200 MB before starting, 100 MB while saving | Estimate the file size first | An extra request per save for little gain; the thresholds catch a full disk before Windows does. |
| 12 | After a failure, ask for the link again only when the message says to check something and try again (not a link, unavailable, no internet, disk full). Otherwise wait for Ruth to close the window. | Always ask again; always wait | "Paste it here" needs a prompt; "close the app and open it again" would contradict one. Either way "the app stays open until Ruth closes it". |
| 13 | Extra on-screen text beyond the approved messages: "Paste the YouTube link here, then press Enter.", a paste hint, "Saving the video. Please wait...", "Saved so far: N%", "Almost done...", "Done! The video is saved in your Videos folder." | Silence between approved messages | Ruth needs to know what to do and that it is working. These are instructions and progress, not failure messages. Run any change past the product owner. |
| 14 | File names: title with `\ / : * ? " < > |` and control characters replaced, `:` becomes ` -`, trimmed, at most 120 characters, reserved names get " video" added, empty becomes "YouTube video" | Use the video id | Ruth recognises the title. Hebrew and other scripts are kept. |
| 15 | The app closes 3 seconds after "Done!" | Close at once | Gives Ruth a moment to see it worked while Explorer opens. |
| 16 | A log at `%LOCALAPPDATA%\easy-yt2mp4\logs\app.log` | No log | Lets someone helping Ruth see what happened; nothing is ever shown to her. |
| 17 | `EASYYT_*` environment variables redirect folders, URLs and timings | Test-only code paths | Lets the integration tests run the real app end to end without touching the real Videos folder or desktop. Ruth never sets them. |
| 18 | Our own tiny test runner (`tests/TestHelpers.ps1`) | Pester | Windows ships Pester 3.4, CI ships 5.x, and their syntax differs. The runner needs nothing installed. |
| 19 | Integration tests run locally only, not in CI | Run in CI | YouTube often bot-checks cloud IPs, which would make CI fail at random. |
| 20 | Test videos: "Me at the zoo" (19 s, 240p only) and Big Buck Bunny (CC BY 3.0, has 720p) | Arbitrary videos | Small, long-lived, and together they cover the 720p path and the fallback. |
| 21 | Squash-merge pull requests; tags `vMAJOR.MINOR.PATCH` publish releases | Merge commits | One commit per change on `main`, and the tag is the only release trigger. |
| 22 | MIT licence for this repo | None | Matches "all components are open-source licensed". |
