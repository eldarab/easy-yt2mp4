# Manual test checklist

Run on a Windows 11 computer. Takes about 20 minutes. Each line maps to a scenario in the ticket.
Automated checks for most of these live in `tests\Integration.Tests.ps1`; this list covers what only a
person at the computer can see.

To start from a clean slate, uninstall first:
`irm https://raw.githubusercontent.com/eldarab/easy-yt2mp4/main/uninstall.ps1 | iex`

## Install

- [ ] In a normal (not admin) PowerShell window, run
      `irm https://raw.githubusercontent.com/eldarab/easy-yt2mp4/main/install.ps1 | iex`.
      It finishes with "Done. Save YouTube Video x.y.z is installed." and asks for no admin rights.
- [ ] A red **Save YouTube Video** icon is on the desktop.
- [ ] Double-clicking it opens a window. It does not open Notepad and shows no execution-policy warning.

## First run and updates

- [ ] First open: the window says "The app is updating. Please wait a moment.", then, after a minute or two,
      asks for the link. Nothing else is asked.
- [ ] Close and open again: the same updating message shows for a few seconds, then it asks for the link.

## Saving

- [ ] Copy the link of a public lecture from the browser's address bar. Paste with Ctrl+V and press Enter.
      Within a second the window says "Saving the video. Please wait..." and a percentage starts to climb.
- [ ] When done, Explorer opens the Videos folder with the new file highlighted, named after the video title,
      ending in `.mp4`. The app window closes by itself.
- [ ] The file plays in the Windows Media Player (or Films & TV) with picture and sound. If it doesn't, it plays in VLC.
- [ ] Right-click the file > Properties > Details: frame height is 720 for a video that offers 720p.
- [ ] Save the same link again: the new file is called "<title> (2).mp4" and the first file is unchanged.
- [ ] A link copied with YouTube's **Share** button (`https://youtu.be/...`) also works.

## When saving fails

For each, check the exact message, that the window stays open, and that nothing new appears in Videos.

- [ ] Press Enter without pasting anything: "This is not a link to a YouTube video..." and it asks again.
- [ ] Paste `hello`: same message, asks again.
- [ ] Paste a link to another site, e.g. `https://vimeo.com/76979871`: same message.
- [ ] Paste `https://www.youtube.com/watch?v=aaaaaaaaaaa`: "This video can't be saved because it is private or no longer on YouTube..."
- [ ] Turn Wi-Fi off, paste a link: "The internet stopped working, so the video was not saved..." Turn Wi-Fi back on.
- [ ] Start saving a long video, turn Wi-Fi off mid-way: the same internet message appears within about 10 seconds,
      and no partial file is in Videos.
- [ ] (Optional) Delete the folder `%LOCALAPPDATA%\easy-yt2mp4\bin`, turn Wi-Fi off and open the app:
      "The app couldn't get ready because the internet isn't working..." Turn Wi-Fi on and open it again: it gets ready.

## Long lecture

- [ ] Save a lecture of about an hour. It usually finishes in about 10 minutes. If it takes longer than
      10 minutes, the window says "Saving is taking longer than usual..." and keeps going until it's done.

## If something looks wrong

The app writes a log to `%LOCALAPPDATA%\easy-yt2mp4\logs\app.log`. Attach it to the bug report.
