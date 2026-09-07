# Session log — 2026-09-07

Built a cmux fork, then discovered it wasn't needed and tore the build down.
Landed on a plan for a harness-configuration tool that requires no fork at all.

**Current state: no fork build is installed.** The source checkout and the GitHub
fork remain. Start at "Where to resume" at the bottom.

---

## 1. The fork — built, verified, then torn down

cmux turned out to be open source (GPL-3.0, 26.8k stars, Swift on Ghostty), so it
was forked rather than reimplemented.

| | |
|---|---|
| Fork | https://github.com/danielteitel/cmux |
| Local | `~/AI/AI-Projects/CMUX2` (3.7 GB), branch `dan/main`, pushed and clean |
| Upstream | `manaflow-ai/cmux` as remote `upstream` |
| Build tag | `dan` → `cmux DEV dan.app`, bundle `com.cmuxterm.app.debug.dan` |

It built and ran: launched from `/Applications`, answered `PONG` on its own
socket, listed workspaces, and reported `cmux 0.64.22 (102) [a33389c33]` — our own
`dan/main` commit, proving the binary came from this fork.

### Then it was removed (§5 explains why)

Deleted: the app (731 MB), `DerivedData/cmux-dan` (8.1 GB),
`~/.cache/cmux/ghosttykit` (505 MB), the `~/.cargo/bin/cmux` and
`~/.local/bin/cmux-dev` shims, all `*com.cmuxterm.app.debug.dan*` state files,
its preferences domain, the `/tmp` sockets and logs, and the Dock tile.

Verified afterwards: `cmux` resolves to `/Applications/cmux.app` again, the real
app is untouched, `~/.config/cmux/cmux.json` unmodified since 22 Jun.

The 9.3 GB is pinned by the Time Machine local snapshot
`com.apple.TimeMachine.2026-09-07-212334.local` until it ages out. That is fine —
that snapshot is also the safety net for everything deleted.

### To rebuild it

```bash
cd ~/AI/AI-Projects/CMUX2
./scripts/setup.sh                        # re-downloads GhosttyKit (~505 MB)
./scripts/install-my-cmux.sh --launch     # build + install + Dock-able
```

About ten minutes. Toolchain is still installed: Zig 0.16.0 (the exact version
Ghostty pins), Bun 1.4.2, Go 1.27.1, plus Xcode 26.3 / Swift 6.2.4 / Rust.

**Two hazards, handled in `install-my-cmux.sh` — do not bypass them.**

- **`reloadp.sh` is unsafe here.** It builds as plain `cmux.app` with the
  *official* bundle id and runs `pkill -x cmux`, killing the real cmux you work
  in. `install-my-cmux.sh` matches on the full executable path instead.
- **Sparkle points at upstream.** `SUFeedURL` is manaflow's appcast with automatic
  checks on, in Debug as well as Release. Left alone the fork would offer to
  "update" itself into the official binary and replace your build. The installer
  disables it in the app's own defaults domain, avoiding an `Info.plist` edit that
  would break the ad-hoc signature.

---

## 2. Why no fork is needed

cmux has extension points that give you panels without touching its source.

| Tier | Vehicle | Cost |
|---|---|---|
| 1 | Saved workspace layouts, automations, event stream, agent hooks, CLI/socket | nothing |
| 2 | Interpreted sidebars (`~/.config/cmux/sidebars/<name>.js`) — left sidebar, right panel, or pane; hot-reloads | nothing |
| 2 | ExtensionKit extension — standalone app, real Swift, filesystem access | Xcode + signing |
| 3 | Fork | 8 GB + permanent merge tax |

**Tier 3 is only for changing cmux's own chrome.** Upstream churn over 90 days:
`Workspace.swift` 346 commits, `ContentView.swift` 255, whole repo 8,361.

**Confirmed present in the release build actually installed** (0.64.22,
`ddd4a01bc`) — so all of this works without rebuilding anything:

```
sidebar <validate|reload|select|open> [name]
right-sidebar <toggle|show|hide|focus|set|mode|files|find|vault|...>
events [--after <seq>] [--cursor-file <path>] [--category <category>] [--reconnect]
hooks · docs [.. sidebars] · new-workspace
```

Caveat: that release is **4,602 commits behind `main`**, so its sidebar runtime is
likely an older subset than `docs/custom-sidebars.md` in the checkout describes.
Use `cmux docs sidebars` from the app itself as the authoritative reference.

Full write-up published as an artifact — **Extend, Don't Fork**:
https://claude.ai/code/artifact/66f846cf-1943-4f3d-b2f0-45ec55ed7328

---

## 3. File navigator — do not build it

cmux already ships a complete file explorer (17 files: `FileExplorerNSOutlineView`,
`FileExplorerStore`, search, keyboard shortcuts, terminal path insertion). It is
`.files`, one of seven `RightSidebarMode` cases, and `.files` is in `paneModes`, so
it can open as a pane today.

**Open it now:** `⌥⌘B` toggles the right sidebar, `⌃1` switches to Files, `⇧⌘E`
focuses it. Inside: `↩` opens the selection, `⇧⌘F` is Find in Directory. (`⌃N` is
positional among *visible* tabs, so the digit changes if you reorder them.)

**Config-only recipe** replacing the planned third column:

1. Command Palette → **Files — Pane**
2. Drag the pane left of the terminal
3. Plus-button menu → **Save Workspace as Layout**
4. Point `ui.newWorkspace.action` at it

Give-up versus a forked column: it is a pane (closable, part of the split) and it
will not retarget to the focused tab's cwd.

**Back up `~/.config/cmux/cmux.json` first** — it is a single fixed path shared by
every cmux build, so a layout saved from any of them changes your real app too.

**Unverified:** that a Files *pane* survives into a saved layout. This is the one
assumption holding the recommendation up.

---

## 4. The harness tool — the actual project

### Prior research on this machine

Already far along, across `SimpleTree1` (1.0 GB), `Harness` (3.1 GB) and the three
installed harness-builder skills:

- **The spine** (`Harness/harness-pa-dev-env/spine-draft-v0.md`) — the ontology:
  nine organs, a constitution, dials. What harness elements *are*.
- **SimpleTree1** — the reconciler: a node graph projected onto real files and
  processes. Node types are already an element taxonomy (`S` Capability writes a
  skill/command/subagent, `G` Guardrails merges settings.json, `M` MCP, `X` Harness).
- **EHB** (`SimpleTree1/harness-node-research/EHB/`) — the composer: an interview
  compiling `method.json`. See `DESIGN.md`, `ANATOMY-REDESIGN-PROPOSAL.md`,
  `SPINE-NATIVE-HARNESS-PROPOSAL.md`, `FEEDBACK-LOG.md`.
- **`.harness.json`** (`SimpleTree3-demo/`) — the portable unit: `{ name, command,
  settings, attachments: [memory | skill | guardrails | prompt] }`.

**None of them is a catalogue.** Nothing browses the elements already on disk.

### The gap, precisely

cmux's config schema contains **no reference to `.claude/`**. It has
`claudeBinaryPath`, agent actions with args, `env`, `cwd`, `setup`, layouts, and
`claudeCodeIntegration` hooks.

> cmux configures **how the agent launches**. Nothing configures **what the agent
> knows or may do.**

### The critique that rewrote the plan

Goal: *make configuring Claude agents in cmux easy to use and clear.* Against it,
the earlier plan failed four ways:

1. **Catalogue ≠ configurator.** A read-only browser makes *finding* easier;
   finding is a means. Vault's one thing is *resume a session* — an action with a
   destination. "Find an element" has none.
2. **Vehicle chosen for build cost, not clarity.** CLI+TUI won because it dodged
   sandbox and signing — the builder's constraints, not the user's. Against this
   goal a TUI is the *worst* option: undiscoverable, keyboard-modal, foreign
   inside a native app. Correct ranking: native panel > config-driven UI > TUI.
3. **Nine organs is the designer's vocabulary.** Organ 6 says simplicity is
   measured from the executor's seat, and SPINE-NATIVE already resolved it:
   *organ-explicit for the designer, simple for the executor.* The user-facing
   layer is the **4 Levers** — Context, Tools, Loop, Governance.
4. **Wrong noun.** Not the element — **the agent in this workspace**. Elements are
   what you add; the effective config is what you look at.

### Revised plan

1. **Resolver first, headless.** *For this directory and agent, what config is
   actually in effect?* Merge project `.claude/`, `~/.claude/`, the CLAUDE.md
   chain, settings permissions and hooks, `.mcp.json` — **with provenance**, every
   rule naming its source file. Vehicle-independent, testable, useful on day one.
2. **First UI is "what is this agent," not the library.** Grouped by 4 Levers,
   showing effective values and provenance.
3. **Then exactly one write verb**, with a diff preview generated by the actual
   writer.
4. **Library last, if ever.**

**The feature only cmux can offer:** agents read config at launch, so a
long-running session is often configured differently from disk. cmux exposes each
agent's `pid`, `status`, `directory` and `transcriptPath`. Show the running agent's
config and diff it against disk — *"your agent is not running the rules you think
it is"* is the most clarifying thing this tool could say.

---

## 5. Security review — why the build came down

The question: could 4,602 unreleased commits contain malicious code?

**Premise corrected.** Those commits *are* merged and committed on
`manaflow-ai/cmux` `main`. What they had not been is *released* — tagged,
Developer-ID signed, notarized.

**Both downloaded binaries are checksum-verified, but not equally:**

| Binary | Verification | Strength |
|---|---|---|
| `GhosttyKit.xcframework` | SHA-256 pinned in `scripts/ghosttykit-checksums.txt`, **committed in the repo**; falls back to a local Zig build on mismatch | Strong |
| `cmux-tui` client | SHA-256 from a manifest **fetched at build time** from `files.cmux.com` | Weaker — checksum and binary share a trust domain |

**The real risk surface.** cmux's entitlements are broad (camera, microphone,
address book, calendars, photos, location, Apple Events, `disable-library-validation`,
`allow-unsigned-executable-memory`). The fork build was **ad-hoc signed and not
notarized** — self-building bypassed Gatekeeper, so Apple's malware scan never ran.
The wider supply chain (15 SPM packages, Rust crates, bun/npm) is a more
conventional attack path than a malicious commit on a heavily-watched repo.

**Not audited:** none of the 4,602 commits were reviewed. Nobody realistically
could. Assessed likelihood: malice unlikely and would be caught fast; unreleased
*bugs* were always the more probable harm.

Conclusion: since no feature needed the fork, running an unnotarized build of
main-HEAD was risk with no upside. Torn down.

---

## 6. Backup gap — worth fixing

Checked which research projects have off-machine copies:

| Project | State |
|---|---|
| `SimpleTree1` | pushed to `danielteitel/SimpleTree` |
| **`Harness`** (3.1 GB) | git repo, **no remote**, 10 uncommitted changes |
| **`SimpleTree3-demo`** | **not a git repo** |
| `ai-workflow`, `ClaudeSkills`, `Orchestra` | not git repos |

Time Machine covers them, but `Harness/` (the spine, `harness-pa-dev-env`) and
`SimpleTree3-demo/` (the `.harness.json` schema) have no version history and no
off-site copy. Offered to commit and push them to private repos; not yet done.

---

## Where to resume

The agreed sequence, with owners:

| # | Who | Step |
|---|---|---|
| 1–3 | — | **Done.** Fork build torn down, disk reclaimed, real setup verified intact |
| **4** | **Daniel** | **Configure a Claude agent once on a real project and narrate it** — what you reached for, what you had to remember, what was unclear |
| **5** | **Daniel** | Say whether the tool is for you alone or for other people too |
| 6 | Claude | Write `harness show` — a CLI printing the config in effect for a directory, with provenance |
| 7 | Daniel | Run it on two or three real projects; say whether it clarifies or just lists files |
| 8 | Claude | Fix what step 7 exposes — likely what it shows, not the code |
| 9 | Claude | Write `~/.config/cmux/sidebars/agents.js` — which agents are running, where, in what state; hot-reloads, no build |
| 10 | Daniel | Live with both for a few days |
| 11 | Both | Pick the vehicle based on what you actually reached for |

Separate and optional, whenever the file navigator is wanted: back up
`cmux.json`, then §3's four-step recipe.

**Steps 4 and 5 gate everything after them.** The plan rests on a guess about that
moment, and the guess was wrong twice in one review.

**Two unverified assumptions:**
- Does a Files pane survive into a saved layout? (holds up §3)
- Can an ExtensionKit extension be anything but the left-sidebar provider?
  (constrains §4's vehicle)

**The recorded design memory is deliberately marked superseded, not deleted** —
the third-column decision is still written down, with a note on top saying
config-only supersedes it, so the call stays yours.
