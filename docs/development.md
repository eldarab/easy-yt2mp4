# Development

Plain Windows PowerShell 5.1, no build step and no modules.

| Path | What it is |
| --- | --- |
| `src/SaveYouTubeVideo.ps1` | The app the desktop icon runs |
| `src/EasyYt2Mp4.ps1` | All the app's functions and the approved wording |
| `install.ps1`, `uninstall.ps1` | The one-line install and removal scripts |
| `tools/Build-Release.ps1` | Builds `dist/easy-yt2mp4.zip`, the release asset `install.ps1` downloads |
| `tools/New-AppIcon.ps1` | Draws `src/icon.ico` |
| `tests/` | Unit tests (offline) and integration tests (real YouTube downloads) |

## Tests

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Unit.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Integration.Tests.ps1
```

CI runs the unit tests and PSScriptAnalyzer on every pull request. The integration tests run locally only,
since YouTube often blocks downloads from cloud servers. They use a throwaway folder and never touch the
real Videos folder or desktop.

The app reads a few `EASYYT_*` environment variables so tests can redirect it: `HOME`, `VIDEOS`, `DESKTOP`,
`NO_WAIT`, `NO_EXPLORER`, `LONG_SECONDS`, `PROBE_HOSTS`, `URL_YTDLP`, `URL_FFMPEG`, `URL_DENO`, `RELEASE_ZIP`.
Ruth never sets any of them.

## Releasing

1. Merge the change to `main` through a pull request.
2. Add a section for the new version at the top of `CHANGELOG.md` (`## 1.2.3`).
3. Tag and push: `git tag -a v1.2.3 -m "v1.2.3"` then `git push origin v1.2.3`.

The Release workflow runs the unit tests, builds `easy-yt2mp4.zip` and publishes the GitHub release.
`install.ps1` always installs the latest release, so running the install command again updates the app.

## Exit codes

0 saved · 2 not a YouTube link · 3 private or removed · 4 no internet · 5 disk full · 6 blocked by YouTube ·
7 no picture and sound · 8 anything else · 9 setup without internet · 10 setup failed otherwise
