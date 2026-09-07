# FORK.md — Daniel's cmux fork

This is a personal fork of [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux),
a GPL-3.0-or-later, Ghostty-based macOS terminal built for running multiple AI
coding agents in parallel.

| | |
|---|---|
| Fork (origin) | https://github.com/danielteitel/cmux |
| Upstream | https://github.com/manaflow-ai/cmux |
| Local checkout | `~/AI/AI-Projects/CMUX2` |
| Build tag | `dan` |
| Dev app name | `cmux DEV dan` |
| Dev bundle id | `com.cmuxterm.app.debug.dan` |

The tag is what keeps this fork's build from colliding with the release
`cmux.app` already in `/Applications`: a tagged build gets its own app name,
bundle id, control socket, and DerivedData path, so both can run at once.

## Build it

One-time (already done; re-run after pulling upstream changes to `ghostty/`):

```bash
./scripts/setup.sh
```

`setup.sh` checks the toolchain, then resolves `GhosttyKit.xcframework` for the
pinned `ghostty/` commit. It downloads a prebuilt xcframework when one exists
for that commit and caches it under `~/.cache/cmux/ghosttykit/`, so the first
run does not compile Ghostty from source. If you move `ghostty/` to a commit
with no prebuilt, it falls back to building with Zig — that is the slow path,
and the reason the exact Zig version matters.

Every build after that:

```bash
./scripts/reload.sh --tag dan --launch   # build Debug + open it
./scripts/reload.sh --tag dan            # build only, kill the running same-tag app
```

Never run bare `xcodebuild` or open an untagged `cmux DEV.app` — untagged builds
share the default debug socket and bundle id with the main app and will steal
focus from it.

Compile-only check, no launch:

```bash
xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/cmux-dan build
```

## The double-clickable app

The tagged build lives in DerivedData, which is not a stable home for something
you keep in the Dock. `scripts/install-my-cmux.sh` copies it to a fixed path:

```bash
./scripts/install-my-cmux.sh                # rebuild, then refresh the installed copy
./scripts/install-my-cmux.sh --launch       # ...and open it
./scripts/install-my-cmux.sh --no-build     # just reinstall what is already built
```

That gives you `/Applications/cmux DEV dan.app` — double-clickable, and pinned
in the Dock as **cmux DEV dan**, next to the release **cmux**.

**Run it after every change.** The Dock tile points at the installed copy, not
at DerivedData, so a plain `reload.sh` will not update what double-clicking
launches. `install-my-cmux.sh` does the build and the refresh together.

The script quits only this tag's copy before replacing it, matching on the full
executable path, so `/Applications/cmux.app` is never touched.

### Why it disables updates

The build inherits upstream's Sparkle feed —
`SUFeedURL = .../manaflow-ai/cmux/releases/latest/download/appcast.xml` with
`SUEnableAutomaticChecks = true` — in Debug as well as Release. Left alone, your
fork would eventually offer to "update" itself into the official cmux binary and
replace your build. The installer writes the Sparkle preferences off in the
app's own defaults domain, which avoids editing `Info.plist` and re-signing:

```bash
defaults write com.cmuxterm.app.debug.dan SUEnableAutomaticChecks -bool false
defaults write com.cmuxterm.app.debug.dan SUAutomaticallyUpdate -bool false
```

### Two things this build is not

- **It is a Debug build** (`-Onone`). It is correct and it runs, but the Swift
  layer is unoptimized. Terminal rendering comes from the prebuilt
  `GhosttyKit.xcframework`, which is compiled `ReleaseFast`, so the typing path
  is not the slow part. If you want an optimized app, build Release with an
  explicit distinct bundle id — never with `reloadp.sh`, which builds as plain
  `cmux.app` with the *official* bundle id and runs `pkill -x cmux`, killing
  your real cmux.
- **It shares the release app's icon.** Both Dock tiles look identical; only the
  labels differ. Changing the icon means editing `Assets.xcassets` (or
  `AppIcon.icon`) and rebuilding — a real change to the fork, not a Dock setting.

## Drive the tagged build from the CLI

```bash
CMUX_TAG=dan scripts/cmux-debug-cli.sh list-workspaces
CMUX_TAG=dan scripts/cmux-debug-cli.sh send --workspace workspace:1 --surface surface:1 "echo ok"
```

The helper refuses to run without `CMUX_TAG`, so it can never target the main
app's socket by accident.

## Where things live

The app is ~8,300 Swift files. The parts you are most likely to touch:

| Path | What lives there |
|---|---|
| `Sources/App/` | `AppDelegate`, window/workspace lifecycle, agent hibernation |
| `Sources/Panels/` | the biggest area — panes, agent session panels, the terminal/browser/diff panel types |
| `Sources/Sidebar/` | vertical tab list, agent activity indicators, drag/reorder |
| `Sources/CommandPalette/` | the Cmd-K palette overlay |
| `Sources/Feed/` | the notification feed and delivery routing |
| `Sources/Surfaces/` | surface providers — local terminals, cloud/TUI mirrors |
| `Sources/Canvas/` | the freeform canvas layout mode |
| `Sources/Settings/` | settings UI and the `~/.config/cmux/cmux.json` config source |
| `Sources/Search/`, `Sources/Find/` | global search index and in-surface find |
| `Sources/Cloud/`, `Sources/Mobile/` | cloud tunnel and the iOS companion |
| `Packages/` | `macOS`, `iOS`, `Shared` Swift packages |
| `Native/` | Rust — `DiffSidecar`, command-palette matcher FFI |
| `ghostty/` | submodule; the terminal engine, consumed as `GhosttyKit.xcframework` |
| `web/`, `webviews/` | TypeScript surfaces (auth pages, markdown viewer, agent chat) |
| `CLI/` | the `cmux` command-line client that talks to the app over its socket |
| `docs/` | upstream design docs — `docs/cli-contract.md`, `docs/events.md`, `docs/configuration.md` are the useful entry points |

`AGENTS.md` and `CLAUDE.md` at the repo root are upstream's own instructions to
coding agents; they are worth reading before changing anything.

## Toolchain this fork needs

| Tool | Version here | Why |
|---|---|---|
| Xcode | 26.3 | builds the Swift/AppKit app |
| Zig | 0.16.0 | builds `GhosttyKit.xcframework` from the `ghostty/` submodule (exact minor required) |
| Rust | cargo 1.93.1 | `Native/DiffSidecar` and the bundled `cmux-cua` engine |
| Go | 1.27.1 | wireguard-go for the Cloud tunnel extension (Release only; Debug gets a stub) |
| Bun | 1.4.2 | `web/`, `webviews/`, and Biome lint |

## What a build touches outside the repo

`reload.sh` installs a dev shim so the `cmux` command can reach a running app:

| Path | What it is |
|---|---|
| `~/.cargo/bin/cmux` | shim managed by `reload.sh`; routes to whichever cmux socket is ambient, so plain `cmux` still hits the release app |
| `~/.local/bin/cmux-dev` | same shim under a dev-only name |
| `/tmp/cmux-cli` | symlink to the most recently reloaded build's CLI — *not* tag-bound, so don't use it in scripts |
| `~/.cache/cmux/ghosttykit/` | cached `GhosttyKit.xcframework` per ghostty commit |
| `~/Library/Developer/Xcode/DerivedData/cmux-dan/` | this tag's build products (~10 GB) |

`~/.cargo/bin/cmux` lands ahead of `/Applications/cmux.app/.../bin/cmux` on PATH.
That is upstream's intended behavior and it still resolves to your main app, but
if you would rather it never be written, build with:

```bash
CMUX_RELOAD_NO_GLOBAL_CLI_LINKS=1 ./scripts/reload.sh --tag dan
```

To tear a tag down completely:

```bash
pkill -f "cmux DEV dan.app/Contents/MacOS/cmux DEV"
rm -rf ~/Library/Developer/Xcode/DerivedData/cmux-dan /tmp/cmux-dan /tmp/cmux-debug-dan.sock
```

## Adding your own things

Not everything needs a Swift change. cmux has extension points that work
without rebuilding, and they are the cheapest place to start:

| Want to | Use | Doc |
|---|---|---|
| Your own sidebar UI | a SwiftUI-style file interpreted at runtime — no Xcode, no build, hot-reloads on save, binds to live cmux state | `docs/custom-sidebars.md` |
| React to app events | `~/.cmuxterm/automations.json` — subscribe to the in-process event bus and run ordered actions | `docs/automations.md`, `docs/events.md` |
| Hook agent lifecycle | `cmux hooks setup <agent>` — running state, Feed approvals, notifications, session restore | `docs/agent-hooks.md` |
| Script the app | the `cmux` CLI over the app's socket | `docs/cli-contract.md` |
| Change settings behavior | `~/.config/cmux/cmux.json` (JSONC, file-managed settings) | `docs/configuration.md` |

A compiled sidebar extension is also possible — see
`Examples/SampleSidebarExtensionApp/`.

When you do need Swift, build with your tag, and keep the change on a branch off
`dan/main` so upstream merges stay manageable.

## Stay current with upstream

```bash
git fetch upstream
git merge upstream/main          # or: git rebase upstream/main
git submodule update --init --recursive
./scripts/setup.sh               # if ghostty/ moved
```

Keep your own work on a branch so upstream merges stay clean.

## Licensing, because it matters for a fork

Upstream is **GPL-3.0-or-later**. Anything you distribute that is built from
this tree stays GPL-3.0-or-later, and you must ship source. Keeping the fork
private and personal is fine; publishing a binary means publishing the source
too. `THIRD_PARTY_LICENSES.md` covers the vendored pieces (Ghostty is MIT,
Bonsplit is MIT, and so on) and those notices have to travel with any build.
