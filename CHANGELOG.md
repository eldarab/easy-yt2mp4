# Changelog

## 1.0.0

First release.

- Paste a YouTube link and the video is saved as an MP4 file in the Videos folder, then shown in Windows Explorer.
- Quality order: 720p H.264 + AAC, then the best H.264 up to 1080p, then the best available put into MP4. Never re-encodes.
- yt-dlp, ffmpeg and Deno are set up automatically the first time the app opens; yt-dlp is updated every time it opens.
- Clear, everyday-language messages for every failure, with no partial files left in the Videos folder.
- One-line install for the current user, no admin rights, with a desktop icon.
