# Session log — 2026-09-07

Two threads ran in this session: **building the cmux fork** (done, working) and
**designing a harness-configuration tool** (open, and the plan was just rewritten
by a critique). Pick up at "Where to resume".

---

## 1. The fork — done and working

| | |
|---|---|
| Fork | https://github.com/danielteitel/cmux |
| Local | `~/AI/AI-Projects/CMUX2`, branch `dan/main`, pushed and clean |
| Upstream | `manaflow-ai/cmux` as remote `upstream` |
| Build tag | `dan` → `cmux DEV dan.app`, bundle `com.cmuxterm.app.debug.dan` |
| Installed | `/Applications/cmux DEV dan.app`, pinned in the Dock (slot 21) |

cmux turned out to be open source (GPL-3.0, 26.8k stars, Swift on Ghostty), so
this is a real fork of real source rather than a reimplementation.

**Verified working**, not just compiled: it launches from `/Applications`, answers
`PONG` on its own socket, lists workspaces, and reports
`cmux 0.64.22 (102) [a33389c33]` — that hash is our own `dan/main` commit, which
proves the running binary came from this fork.

### Rebuild and reinstall

```bash
./scripts/install-my-cmux.sh --launch     # build + refresh the /Applications copy
./scripts/install-my-cmux.sh --no-build   # reinstall what is already built
```

Run **`install-my-cmux.sh`, not `reload.sh`** after code changes. The Dock tile
points at `/Applications`, not DerivedData, so `reload.sh` alone will not change
what double-clicking launches.

### Two hazards, both handled — do not undo them

- **`reloadp.sh` is unsafe here.** It builds as plain `cmux.app` with the
  *official* bundle id and runs `pkill -x cmux`, which kills the real cmux you
  work in. `install-my-cmux.sh` matches on the full executable path instead, so
  it can only ever quit this fork's copy.
- **Sparkle points at upstream.** `SUFeedURL` is manaflow's appcast with
  automatic checks on, in Debug as well as Release. Left alone the fork would
  offer to "update" itself into the official binary and replace your build. The
  installer disables it in the app's own defaults domain (no `Info.plist` edit,
  so the ad-hoc signature stays valid).

Toolchain installed this session: Zig 0.16.0 (exact version Ghostty pins), Bun
1.4.2, Go 1.27.1. Xcode 26.3, Swift 6.2.4 and Rust were already present.

Disk went from ~57 GB free to ~38 GB (1.7 GB checkout + ~8 GB DerivedData).

---

## 2. What cmux already has — the finding that changed everything

We were about to fork a 93-commit-a-day app to add two panels. cmux has
first-class extension points that give you panels without forking.

| Tier | Vehicle | Cost |
|---|---|---|
| 1 | Saved workspace layouts, automations, event stream, agent hooks, CLI/socket | nothing |
| 2 | Interpreted sidebars (`~/.config/cmux/sidebars/<name>.js`) — left sidebar, right panel, or pane; hot-reloads | nothing |
| 2 | ExtensionKit sidebar extension — standalone app, real Swift, filesystem | Xcode + signing |
| 3 | Fork the app | 8 GB + merge tax |

**Tier 3 is only for changing cmux's own chrome.** Upstream churn over 90 days:
`Workspace.swift` 346 commits, `ContentView.swift` 255, whole repo 8,361.

Full write-up published as an artifact: **Extend, Don't Fork** —
https://claude.ai/code/artifact/66f846cf-1943-4f3d-b2f0-45ec55ed7328

---

## 3. File navigator — superseded, do not build

cmux already ships a complete file explorer (17 files: `FileExplorerNSOutlineView`,
`FileExplorerStore`, search, keyboard shortcuts, terminal path insertion). It is
`.files`, one of seven `RightSidebarMode` cases, and `.files` is in `paneModes`
so it can open as a pane today.

**Config-only recipe** (replaces the planned third column):

1. Command Palette → **Files — Pane**
2. Drag the pane left of the terminal
3. Plus-button menu → **Save Workspace as Layout**
4. Point `ui.newWorkspace.action` at it

Give-up versus a forked column: it is a pane (closable, part of the split), and
it will not retarget to the focused tab's cwd. Not worth the merge tax.

**Unverified:** that a Files *pane* actually survives into a saved layout. This
is the one assumption holding the recommendation up. Five-minute test.

### How to open the explorer right now

`⌥⌘B` toggles the right sidebar, `⌃1` switches it to Files, `⇧⌘E` focuses it.
Inside: `↩` opens the selection, `⇧⌘F` is Find in Directory. (`⌃N` is positional
among *visible* sidebar tabs, so the digit changes if you reorder them.)

---

## 4. The harness tool — plan rewritten, decision pending

### Prior research found on this machine

Already unusually far along, across `SimpleTree1` (1.0 GB), `Harness` (3.1 GB),
and the three installed harness-builder skills:

- **The spine** (`Harness/harness-pa-dev-env/spine-draft-v0.md`) — the ontology:
  nine organs, a constitution, dials. What harness elements *are*.
- **SimpleTree1** — the reconciler: a node graph projected onto real files and
  processes. Node types are already an element taxonomy (`S` Capability writes a
  skill/command/subagent, `G` Guardrails merges settings.json, `M` MCP, `X` Harness).
- **EHB** (`SimpleTree1/harness-node-research/EHB/`) — the composer: an interview
  compiling `method.json`. Read `DESIGN.md`, `ANATOMY-REDESIGN-PROPOSAL.md`,
  `SPINE-NATIVE-HARNESS-PROPOSAL.md`, `FEEDBACK-LOG.md`.
- **`.harness.json`** (`SimpleTree3-demo/`) — the portable unit: `{ name, command,
  settings, attachments: [memory | skill | guardrails | prompt] }`.

**None of them is a catalogue.** Nothing browses the elements already on disk.

### The gap, stated precisely

cmux's config schema contains **no reference to `.claude/`**. It has
`claudeBinaryPath`, agent actions with args, `env`, `cwd`, `setup`, layouts, and
`claudeCodeIntegration` hooks.

> cmux configures **how the agent launches**. Nothing configures **what the agent
> knows or may do.**

### The critique that rewrote the plan

Stated goal: *make configuring Claude agents in cmux easy to use and clear.*
Against that goal the earlier plan failed on four counts:

1. **Catalogue ≠ configurator.** A read-only browser makes *finding* easier;
   finding is a means. Vault's one thing is *resume a session* — an action with a
   destination. "Find an element" has none.
2. **Vehicle chosen for build cost, not clarity.** CLI+TUI won because it dodged
   sandbox/signing — my constraints, not the user's. Against this goal a TUI is
   the *worst* option: undiscoverable, keyboard-modal, visually foreign in a
   native app. Correct ranking: native panel > config-driven UI > TUI.
3. **Nine organs is the designer's vocabulary.** Organ 6 says simplicity is
   measured from the executor's seat, and SPINE-NATIVE already resolved this:
   *organ-explicit for the designer, simple for the executor.* The user-facing
   layer is the **4 Levers** (Context, Tools, Loop, Governance).
4. **Wrong noun.** Not the element — **the agent in this workspace**. Elements
   are what you add; the effective config is what you look at.

### Revised plan (not yet accepted)

1. **Resolver first, headless.** *For this directory and agent, what config is
   actually in effect?* Merge project `.claude/`, `~/.claude/`, the CLAUDE.md
   chain, settings permissions/hooks, `.mcp.json` — **with provenance**, every
   rule naming its source file. Vehicle-independent, testable, useful as
   `harness show` on day one.
2. **First UI is "what is this agent," not the library.** Grouped by 4 Levers,
   showing effective values and provenance.
3. **Then exactly one write verb**, with a diff preview generated by the actual
   writer.
4. **Library last, if ever.**

**The feature only cmux can offer:** agents read config at launch, so a
long-running session is often configured differently from disk. cmux knows each
agent's `pid`, `status`, `directory`, `transcriptPath`. Show the running agent's
config and diff it against disk — "your agent is not running the rules you think
it is" is the most clarifying thing this tool could say.

---

## Where to resume

**Two open questions, both yours:**

1. **Is "the user" you alone, or other people?** A personal tool can be a TUI and
   discoverability stops mattering. Anything for other people cannot be, which
   pushes the native-panel question — and the unresolved ExtensionKit placement
   limit — to the front.
2. **Do you accept the revised plan** (resolver-first, 4 Levers, agent-as-noun)?

**The one thing worth doing before more design:** configure a Claude agent once
and narrate it — what you reached for, what you had to remember, what was
unclear. The whole plan rests on a guess about the job-to-be-done, and that guess
was wrong twice in one review.

**Two unverified assumptions:**
- Does a Files pane survive into a saved layout? (holds up §3)
- Can an ExtensionKit extension be anything but the left-sidebar provider?
  (constrains §4's vehicle)

**Recorded design memory is deliberately stale.** It still says the third-column
file navigator is accepted. Left that way so the decision stays yours.
