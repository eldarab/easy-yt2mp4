# US-001 Ticket: Save a YouTube lecture to the Videos folder

| | |
| --- | --- |
| Status | Shipped in v1.0.0 (2026-11-23) |
| Product owner | Eldar Abraham |
| Original | claude.ai doc "Ticket: Save a YouTube lecture to the Videos folder" (private to the product owner). This file is the copy of record in the repo. |
| How it was built | [US-001 decisions](../decisions/US-001-decisions.md) |

The text below is the ticket as approved, unchanged.

---

## User story

**As a** viewer with low confidence using technology, **who** found a lecture that will be removed from YouTube in a week, **I want** to save it to my computer with as few steps as possible and be shown where it is, **so that** I can rewatch it whenever I want, even after it's removed.

**Persona:** Ruth, 60+, uncomfortable with technology.

## Context for engineering

- **Intended flow:** Ruth copies the YouTube link, double-clicks the app icon on her Windows desktop, pastes the link and gets the file shown to her.
- **Current implementation:** a PowerShell script where she pastes the link and presses Enter. This is acceptable to her. A button would be nice but is not required. The acceptance criteria below describe behavior only, not UI.
- **Licensing:** all components are open-source licensed.
- **Assumptions:** the Windows Videos folder exists. Lectures on YouTube always have sound. VLC is installed on Ruth's computer.
- **Length:** no limit on video length. A typical lecture is about 65 minutes.
- **Target and testing:** Windows 11. Eldar (the product owner) tests on his Windows 11 desktop and Windows 11 laptop. Deliver the files plus a short manual test checklist he can run on Windows.

## Before dispatching

Eldar checks these before handing the ticket to Claude, so it can work without stopping:

- [ ] The repo https://github.com/eldarab/easy-yt2mp4 doesn't need to exist yet. Claude creates it if it's missing.
- [ ] The repo is created as public, so the one-line install command can fetch `install.ps1` without signing in.
- [ ] The Claude session that builds this can create repos on the eldarab GitHub account and push to them.
- [ ] Claude runs on a Windows 11 machine with PowerShell, Git and internet access to GitHub and YouTube, so it can run and test the app itself.
- [ ] VLC is installed on Eldar's Windows 11 desktop and laptop.

## Technical requirements

- **Downloader:** use yt-dlp with its dependencies: ffmpeg (combines picture and sound into one file) and Deno (the JavaScript runtime yt-dlp needs to work with YouTube). All three are portable and kept inside the app's folder.
- **Runtime:** PowerShell, so it runs natively on Windows with nothing extra to install.
- **Updates:** first-time setup (yt-dlp, ffmpeg and Deno) and the yt-dlp update check run automatically each time the app opens. Every time they run, the app tells Ruth it is updating. She does nothing.
- **Quality order:** (1) 720p with H.264 video and AAC audio; (2) if that is not available or fails, the best H.264 video up to 1080p; (3) otherwise, the best quality available, put into an MP4 file. Never re-encode.
- **No configuration:** Ruth never configures anything. Pasting the link is her only input.
- **File format:** the saved file must be MP4. H.264 and AAC let the default Windows player play it. If the quality order ends on another format, VLC plays it.
- **Installation:** Eldar installs the app once, not Ruth. He runs one PowerShell command like `irm https://raw.githubusercontent.com/eldarab/easy-yt2mp4/main/install.ps1 | iex`, with `install.ps1` hosted on GitHub (repo: https://github.com/eldarab/easy-yt2mp4). It installs the app into `%LOCALAPPDATA%` without admin rights and creates a desktop icon that runs the app with `powershell.exe -NoProfile -ExecutionPolicy Bypass`, so double-clicking it never opens Notepad or hits the execution policy.
- **Speed:** a typical 65-minute lecture should usually save in about 10 minutes. This is a rule of thumb, not a test target. Never stop or fail a download because it takes longer.

## Acceptance criteria

### Starting and saving

```gherkin
Scenario: Eldar installs the app with one command
Given Eldar is on Ruth's Windows 11 computer
When he runs the one-line install command in PowerShell
Then the app's icon appears on Ruth's desktop
And no admin rights are needed
And double-clicking the icon opens the app
```

```gherkin
Scenario: First-time setup happens by itself when the app opens
Given the app's icon is on Ruth's Windows desktop
And yt-dlp, ffmpeg and Deno are not yet set up
When Ruth opens the app
Then she sees the message "The app is updating. Please wait a moment."
And everything the app needs is set up without asking her anything
And then the app asks her for the video link
```

```gherkin
Scenario: The app updates itself when it opens
Given a newer version of yt-dlp has been released
When Ruth opens the app
Then she sees the message "The app is updating. Please wait a moment."
And yt-dlp is updated to the newest version without asking her anything
And then the app asks her for the video link
```

```gherkin
Scenario: The app is already up to date
Given the app is set up and yt-dlp is the newest version
When Ruth opens the app
Then she sees the message "The app is updating. Please wait a moment." while it checks for updates
And then the app asks her for the video link
And she does not need to install anything, sign in or change settings
```

```gherkin
Scenario: An update cannot be completed
Given the app is set up
And a newer version of yt-dlp cannot be installed
When Ruth opens the app
Then she sees the message "The app is updating. Please wait a moment."
And then the app asks her for the video link
And it saves videos with the yt-dlp version it already has
And Ruth is not shown any message about the failed update
```

```gherkin
Scenario Outline: First-time setup cannot be completed
Given yt-dlp, ffmpeg and Deno are not yet set up
And <situation>
When Ruth opens the app
Then she sees the message "<message>"
And the app stays open until Ruth closes it

Examples:
| situation | message |
| her internet is off | The app couldn't get ready because the internet isn't working. Please check that your internet is on, then open the app again. |
| setup fails for any other reason | The app couldn't get ready. Please close it and open it again. If it happens again, ask someone to help you. |
```

```gherkin
Scenario: Ruth knows the app has started working
Given Ruth has the link of a public YouTube video
When Ruth gives the link to the app
Then within 1 second she sees that saving has started
```

```gherkin
Scenario: Ruth saves a lecture
Given Ruth has the link of a public YouTube video titled "Lecture"
And the Videos folder has no file named "Lecture.mp4"
When Ruth gives the link to the app
Then the video is saved to the Videos folder as "Lecture.mp4"
And Windows Explorer shows the Videos folder with "Lecture.mp4" highlighted
And the app closes itself
```

```gherkin
Scenario: A file with the same name already exists
Given the Videos folder already has a file named "Lecture.mp4"
When Ruth saves another video titled "Lecture"
Then the new file is saved as "Lecture (2).mp4"
And the existing "Lecture.mp4" is unchanged
And Windows Explorer highlights "Lecture (2).mp4"
```

### The saved file

```gherkin
Scenario: The saved lecture has motion and sound
Given Ruth has the link of a public YouTube video that has picture and sound
When the video is saved
Then the saved file contains moving picture
And the saved file contains sound
```

```gherkin
Scenario: The lecture is saved as an MP4 file
Given Ruth has the link of a public YouTube video titled "Lecture"
When the video is saved
Then the saved file is an MP4 file named "Lecture.mp4"
```

```gherkin
Scenario: The saved lecture plays on her computer
Given "Lecture.mp4" is saved in the Videos folder
When Ruth opens the file
Then it plays in the default Windows player, or in VLC
And nothing else needs to be installed
```

### Quality

```gherkin
Scenario: The lecture is saved in 720p without Ruth choosing
Given the YouTube video is available in 720p
When Ruth gives the link to the app
Then the saved file is in 720p
And Ruth is not asked about quality, format or any other setting
```

```gherkin
Scenario Outline: The app falls back to the best quality it can download
Given <situation>
When Ruth gives the link to the app
Then the app saves the video in the best quality it can download
And the saved file has moving picture and sound
And Ruth is not asked anything

Examples:
| situation |
| the YouTube video is not available in 720p |
| saving the video in 720p fails |
```

### When saving fails

```gherkin
Scenario Outline: Ruth is told clearly why the video was not saved
Given <situation>
When Ruth gives the link to the app
Then within 10 seconds of the problem she sees the message "<message>"
And no file or partial file is left in the Videos folder
And the app stays open until Ruth closes it

Examples:
| situation | message |
| Ruth has given nothing, random text, or a link to another website | This is not a link to a YouTube video. Please copy the link again from the YouTube page and paste it here. |
| the video is private, removed or blocked | This video can't be saved because it is private or no longer on YouTube. Please check that you can still watch it on YouTube. |
| her internet is off, or drops while saving | The internet stopped working, so the video was not saved. Please check that your internet is on, then try again. |
| there is not enough space on her computer | Your computer is too full to save this video. Please delete some files you don't need, or ask someone to help you, then try again. |
| YouTube blocks the download | YouTube isn't letting the app save this video right now. Please close the app, open it again, and try once more. If it still doesn't work, try again tomorrow. |
| the video cannot be saved with both picture and sound | The video couldn't be saved with both picture and sound, so nothing was saved. Please close the app, open it again, and try once more. |
| any other problem | Something went wrong and the video was not saved. Please close the app, open it again, and try once more. If it happens again, ask someone to help you. |
```

```gherkin
Scenario: Saving takes much longer than usual
Given Ruth has given the app the link of a public YouTube video
And saving has been running for about 10 minutes without a failure
When saving is still not finished
Then she sees the message "Saving is taking longer than usual. Please keep this window open and wait a little longer."
And the app keeps saving the video until it finishes
```

**Rules for every failure message**

- It says what happened, then what to do next.
- It uses everyday words only. No error codes and no technical terms such as "error", "download failed" or "invalid URL".
- It never blames Ruth.
- Messages that ask her to close and reopen the app do so because reopening runs the yt-dlp update, which fixes most YouTube-side problems.
- A failed yt-dlp update shows no message. The app carries on with the version it has.
- The wording above is approved by the product owner. Changes go back to the product owner.

## Out of scope

- Playlists
- Letting Ruth choose video quality or file format (the app chooses for her)
- Video sites other than YouTube
- Mac, phone or tablet
- Videos that have no sound
- Checking that sound and picture are in sync
- A missing or moved Videos folder
