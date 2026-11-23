# CLAUDE.md

Guide for anyone (human or AI agent) picking up this repo cold. Read this file, then the docs it points to.

## What this is

**Save YouTube Video** (repo `eldarab/easy-yt2mp4`): a Windows 11 app that saves a YouTube video as an MP4
file in the Videos folder. It is built for **Ruth**, a fictional name for a real person, 60+, who is
uncomfortable with technology. She double-clicks a desktop icon, pastes a link, presses Enter, and Explorer
shows her the saved file. **Eldar Abraham** is the product owner: he writes the user stories, installs the app
for Ruth, approves every word she sees, and tests on his Windows 11 desktop and laptop.

Current version and history: [CHANGELOG.md](CHANGELOG.md).

## Read first

| Doc | What you get |
| --- | --- |
| [docs/specs/](docs/specs/) | Every user story as approved, with Gherkin acceptance criteria. US-001 is the original ticket. |
| [docs/architecture.md](docs/architecture.md) | How the app works step by step, runtime folders, failure handling, and which test covers which scenario |
| [docs/decisions/](docs/decisions/) | Calls made during each story, with the alternatives and why. Don't re-argue these without a reason. |
| [docs/development.md](docs/development.md) | Files, tests, test environment variables, releasing, exit codes |
| [docs/manual-test-checklist.md](docs/manual-test-checklist.md) | What Eldar checks by hand on Windows |

## Product rules (never break these)

1. **Ruth's only input is pasting a link.** No settings, no questions, no choices, no sign-in.
2. **Approved wording is fixed.** Every failure message in `$script:Messages` (src/EasyYt2Mp4.ps1) is approved by
   the product owner and pinned by a unit test. Changing or adding text Ruth sees goes back to Eldar.
3. **Failure messages** say what happened, then what to do next; use everyday words (never "error", "download
   failed", "invalid URL", codes); never blame Ruth.
4. **Nothing partial in Videos.** Work happens in `%LOCALAPPDATA%\easy-yt2mp4\work`; only a finished, checked
   file is moved into Videos.
5. **Never re-encode.** ffmpeg only merges and remuxes. Output is always MP4.
6. **No admin rights, nothing to install** beyond the one-line command. Everything is open-source licensed.
7. **Windows PowerShell 5.1** (`powershell.exe`), not PowerShell 7. It is the only runtime guaranteed on Ruth's PC.

## How to deliver a new user story

1. **Spec.** Copy [docs/specs/TEMPLATE.md](docs/specs/TEMPLATE.md) to `docs/specs/US-NNN-short-name.md` (next
   number). If Eldar gave you the story elsewhere (a claude.ai doc, an issue), copy it in verbatim; it is the copy
   of record. Behaviour goes in Gherkin scenarios; any new words Ruth sees go in as exact quoted text.
2. **Branch** from an up-to-date `main`: `feat/US-NNN-short-name` (or `fix/...`, `docs/...`).
3. **Build** in `src/`. Keep `SaveYouTubeVideo.ps1` thin; put logic in testable functions in `EasyYt2Mp4.ps1`.
4. **Test.** Add unit tests to `tests/Unit.Tests.ps1` for every pure function, and an integration test in
   `tests/Integration.Tests.ps1` for each scenario that can run against real YouTube. Run both (commands below)
   and read the output; don't claim a pass you didn't see.
5. **Document.** Update `docs/architecture.md` (flow and the scenario-to-test table),
   `docs/manual-test-checklist.md`, and write `docs/decisions/US-NNN-decisions.md` for every call the spec didn't
   settle. Add a `## x.y.z` section at the top of `CHANGELOG.md` (semver: new behaviour = minor, fix = patch).
6. **Pull request** using the template; CI must be green (unit tests, PSScriptAnalyzer, release build).
   Squash-merge and delete the branch.
7. **Release.** On `main`: `git tag -a vX.Y.Z -m "vX.Y.Z"` then `git push origin vX.Y.Z`. The Release workflow
   publishes `easy-yt2mp4.zip`. Check the release exists, then run the README's install command and do one real
   save with the installed copy (use `EASYYT_HOME`/`EASYYT_VIDEOS` pointing at a temp folder so Eldar's own
   install and Videos folder stay untouched).
8. **Hand back** a link to the README (or the release) and a short list of the calls you made.

## Working with Eldar

- **Work autonomously.** Don't stop to ask for decisions. When there is a dilemma, compare the alternatives,
  pick the recommended and simplest one, record it in the story's decisions file, and keep going until done.
- **Proper git workflow every time:** branch, pull request, green CI, squash-merge, changelog, tag, GitHub release.
- **Boy scout rule:** leave the repo cleaner and better documented than you found it, so the next person or agent
  can pick it up with no other context.
- **Exceptions that still need Eldar:** new or changed words Ruth sees, anything that widens scope beyond the
  spec's "Out of scope" list, and anything that costs money or touches accounts other than this repo.

## Setting up a new machine

- Windows 11 with Windows PowerShell 5.1 (built in), Git, and the GitHub CLI (`gh`) signed in to an account
  that can push to `eldarab/easy-yt2mp4` (`gh auth status` to check). Internet access to GitHub and YouTube.
- `git clone https://github.com/eldarab/easy-yt2mp4` and run the unit tests. Nothing else to install: the
  integration tests download yt-dlp, ffmpeg and Deno into a temp folder themselves.
- If this machine also has the app installed for real, it lives in `%LOCALAPPDATA%\easy-yt2mp4` with a desktop
  icon. Leave it alone unless you are testing the install itself.

## Commands

```powershell
# Unit tests: offline, about 5 seconds
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Unit.Tests.ps1

# Integration tests: real YouTube, a few minutes, uses a throwaway folder
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Integration.Tests.ps1

# Run the app from source, the way the desktop icon does
powershell -NoProfile -ExecutionPolicy Bypass -File src\SaveYouTubeVideo.ps1

# Build the release zip locally (dist\ is git-ignored)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Build-Release.ps1 -Version 1.2.3
```

When running the app from source on a dev machine, set `EASYYT_HOME` and `EASYYT_VIDEOS` to a temp folder unless
you mean to use the real install. See [docs/development.md](docs/development.md) for every `EASYYT_*` variable.

## Pitfalls already found

- **Keep every `.ps1` file ASCII.** Windows PowerShell 5.1 reads BOM-less files as ANSI, so a smart quote or
  em dash corrupts strings. A unit test enforces this.
- **`Start-Process -ArgumentList` does not quote arguments in 5.1.** Build the command line with
  `ConvertTo-ArgumentString`.
- **Read `$p.Handle` right after `Start-Process -PassThru`,** or `$p.ExitCode` comes back empty.
- **With `$ErrorActionPreference = 'Stop'`, native stderr can throw.** Set it to `'Continue'` locally around
  native calls whose stderr you discard.
- **`Read-Host` appends ": "** to the prompt; the app uses `[Console]::ReadLine()` instead.
- **YouTube changes often.** yt-dlp needs Deno to solve YouTube's JavaScript challenges, and the app runs
  `yt-dlp -U` on every open. If downloads start failing, update yt-dlp first and read `logs\app.log`.
- **YouTube bot-checks cloud machines**, so integration tests don't run in CI. Run them locally before every release.
- **`System.Drawing.Icon` can't read PNG-based icons,** but Windows can. Check `src/icon.ico` by extracting the
  PNG, not with `Icon.ToBitmap()`.

## Conventions

- Commit messages: imperative summary line, then a short body on what and why.
- Branches: `feat/`, `fix/`, `docs/`, `chore/`. Never commit straight to `main`.
- User-facing text lives only in `$script:Messages`; code never builds Ruth's sentences inline.
- Don't add dependencies. If one is truly needed, it must be portable, open source, and downloaded into `bin\`
  by the app's setup step.
