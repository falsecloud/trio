# trio

**A terminal UI that runs 3 [opencode](https://opencode.ai) agents in parallel and combines their work into one result.**

You type a prompt once. Three agents attack it at the same time, each with a slightly different approach (simplest, most robust, most performant). A judge then picks the best answer, or merges them, and you get a single result. In CODE mode the winning change is applied straight to your repo.

> Status: small, lightly tested hobby project. It shells out to the `opencode` CLI, so it depends on that CLI's behaviour. Read [Known limitations](#known-limitations) before pointing it at work you care about.

---

## Contents

- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Install](#install)
- [Usage](#usage)
- [Speed and cost](#speed-and-cost)
- [Known limitations](#known-limitations)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Reporting bugs](#reporting-bugs)
- [License](#license)

---

## How it works

```
                        your prompt
                             |
          +------------------+------------------+
          v                  v                  v
       agent 1            agent 2            agent 3     3 parallel `opencode run`s,
      (simplest)         (robust)          (performant)  each with a different approach
          |                  |                  |
          +------- first N finish (quorum) -----+        slow stragglers are killed
                             v
                           judge                         picks a winner, or merges
                             v
                 final answer / applied diff
```

### Modes (press `Tab` to cycle)

| Mode | What runs | Best for |
|------|-----------|----------|
| **FAST** | One warm agent, no judge | Quick questions and small edits |
| **ASK** | 3 read-only agents, then a judge | Explanations, code review, design questions |
| **CODE** | 3 agents, each in its own git worktree, then a judge | Changes you want cross-checked before they touch your repo |

trio starts in **FAST**. In ASK mode, very short prompts (3 words or fewer, no question mark, e.g. "hi") are automatically run in FAST, because three agents plus a judge is pointless for a greeting.

### The pieces

- **Warm server.** On launch, trio starts one `opencode serve` on a random localhost port. Runs use `opencode run --attach <url>` so agents don't pay a cold start each time. If `--attach` isn't supported by your opencode version, trio notices the failure, retries without it, and carries on (the "warm" dot in the top bar turns grey).
- **Quorum.** Once N of the 3 agents finish successfully (default 2), the remaining one is killed instead of waited on. Change it with `/quorum`.
- **Judge.** The judge usually answers with just `WINNER: <n>`, which is cheap and fast. It only writes a merged answer when the agents each contributed something the others lacked. In ASK mode the judge is skipped entirely when the first two answers are at least 80% similar.
- **CODE mode internals.** trio snapshots your tracked changes with `git stash create`, creates three detached worktrees from that snapshot, and lets one agent edit in each. It collects each diff (`git diff --cached --binary`), and the judge replies `WINNER: <n>` or `COMBINE`. A winner is applied to your working tree with `git apply` (falling back to `--3way`). On `COMBINE`, or if the patch won't apply, one agent re-implements the best mix in your repo. Worktrees are removed afterwards.
- **Context.** The last three exchanges are included in each new prompt, so follow-ups work. `/new` resets it.

---

## Requirements

| Dependency | Version | Notes |
|------------|---------|-------|
| Linux | any | Developed on CachyOS (Arch-based) with kitty. Other distros should work via pip. |
| Python | 3.10+ | |
| [Textual](https://textual.textualize.io) | recent | `python-textual` on Arch. Pulls in `rich`. |
| [opencode](https://opencode.ai) | recent | Must be in your `PATH` and logged in to at least one model provider. |
| git | any | Required for CODE mode (and it must be run inside a git repo). |
| GitHub CLI (`gh`) | optional | Only needed if you want to publish a repo like this one. |

Your terminal should support UTF-8 and 256 colours or more (kitty, alacritty, wezterm, foot, gnome-terminal all do).

---

## Install

### Quick install

```bash
git clone https://github.com/falsecloud/trio.git
cd trio
./install.sh
```

The installer:

1. checks for Python 3.10+;
2. installs Textual (`sudo pacman -S --needed python-textual` on Arch-based systems, `pip install --user textual` elsewhere);
3. copies `trio` to `~/.local/bin/trio`;
4. tells you if `~/.local/bin` is missing from your `PATH` and how to fix it;
5. confirms Textual imports and warns if `opencode` isn't found.

Options: `PREFIX=/some/dir ./install.sh` changes the install prefix, and `SKIP_DEPS=1 ./install.sh` skips step 2.

### Manual install

```bash
# Arch / CachyOS / Manjaro / EndeavourOS
sudo pacman -S --needed python-textual git

# other distros
python3 -m pip install --user textual

install -Dm755 trio ~/.local/bin/trio
```

Make sure `~/.local/bin` is in your `PATH`:

```bash
# bash / zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# fish
fish_add_path ~/.local/bin
```

Then install and log in to opencode (see <https://opencode.ai>) and check that `opencode run "say hi"` works on its own before trying trio.

---

## Usage

Run `trio` inside the project you want to work on:

```bash
cd ~/my-project
trio
```

The top bar shows the current mode, quorum, models, whether the warm server is up, and the folder.

After each result trio prints a dim timing line, for example `ASK · 74s total · a1 40s · a2 52s · judge 22s · warm`, showing how long each step took and whether the warm server was used.

### Keys

| Key | Action |
|-----|--------|
| `Tab` | Cycle FAST / ASK / CODE |
| `Enter` | Send the prompt |
| `Ctrl+X` | Cancel the running job (kills the agents) |
| `Ctrl+L` | Clear the screen |
| `Ctrl+Q` or `Ctrl+C` | Quit |

### Slash commands

| Command | Effect |
|---------|--------|
| `/mode fast\|ask\|code` | Set the mode |
| `/model a[,b,c]` | Models for agents 1-3, as `provider/model`. One value is reused, several are cycled. No value resets to opencode's default. |
| `/judge model` | Model for the judge. No value resets to default. |
| `/quorum 1\|2\|3` | How many agents must finish before the judge runs |
| `/warm on\|off` | Turn the warm opencode server on or off (off = every run cold-starts; handy for diagnosing slowness) |
| `/new` | Forget conversation context |
| `/clear` | Clear the screen |
| `/cancel` | Cancel the running job |
| `/quit` | Exit |
| `/help` | Show help in the app |

### Getting better results

- Give the agents **different models** (`/model modelA,modelB,modelC`). Different models disagree more usefully than three runs of one model.
- Give the judge your **strongest** model (`/judge modelX`) and the agents faster ones.
- **Commit before CODE runs.** The winning change is written into your working tree.
- Use **FAST** for anything small. The 3-agent modes are for questions where a second and third opinion is worth the tokens.

---

## Speed and cost

- trio uses roughly **3-4x the tokens** of a single opencode run (three agents plus a judge). Quorum and killed stragglers reduce this a little.
- Parallelism, the warm server, quorum, and the judge-picks-a-winner shortcut all aim to cut wall-clock time. A 3-agent run is still usually slower than a single FAST run, because you wait for at least two agents plus the judge.
- No benchmarks are claimed here. If you measure it, open an issue with your numbers.

---

## Known limitations

- The warm-server speedup assumes `opencode run --attach` exists in your opencode version. If not, trio falls back silently and loses that speedup.
- CODE mode snapshots **tracked** files only. Untracked new files are not visible to the agents until you `git add` them.
- The winning change is applied directly to your working tree. Commit first.
- The prompt box is single-line. For long prompts, put the details in a file in your repo and tell trio to read it.
- Agents can't ask you questions mid-run. Each one works headless.
- The judge is itself an LLM and can pick the wrong winner. Review the diff (`git diff`) before committing.
- Tested lightly, mainly on CachyOS with kitty.

---

## Troubleshooting

### `trio: command not found`
`~/.local/bin` isn't in your `PATH`. See [Manual install](#manual-install) for the bash/zsh/fish lines, then open a new terminal. Check with `which trio`.

### `ModuleNotFoundError: No module named 'textual'`
Textual isn't installed for the Python that runs `trio`.
```bash
sudo pacman -S --needed python-textual        # Arch-based
python3 -m pip install --user textual         # others
python3 -c "import textual; print(textual.__version__)"
```
If you use a virtualenv or pyenv, the `python3` on your `PATH` may differ from the system one. `trio` uses `#!/usr/bin/env python3`, so activate an environment that has Textual or install it system-wide.

### On Python 3.10 or older: syntax or typing errors
trio needs Python 3.10+. Check with `python3 --version`.

### `opencode not found in PATH` (shown in the app)
Install opencode from <https://opencode.ai>, then check `which opencode`. If it lives somewhere unusual, add that folder to `PATH`.

### Every agent fails ("all agents failed")
trio just runs `opencode run`, so test that directly:
```bash
opencode run "say hi"
```
If that fails, fix opencode first: log in to a provider, check the model name, check your network and API quota. If you set `/model` or `/judge`, make sure the `provider/model` string is valid, or reset with `/model` and `/judge` with no argument.

### The "warm" dot in the top bar is grey
The warm server isn't in use. Either `opencode serve` failed to start, or `--attach` isn't supported by your version. trio still works, just without the cold-start savings. Check `opencode serve --help` and `opencode run --help`. If a stale server is stuck: `pkill -f "opencode serve"` and restart trio.

### `CODE mode needs a git repo`
Run trio from inside a git repository, or use ASK/FAST mode. To start one: `git init && git add -A && git commit -m init`.

### `worktree failed: ...`
Usually a stale worktree from a crashed run. Clean up:
```bash
git worktree prune
rm -rf /tmp/trio-*
```
It can also happen in a repo with no commits yet. Make an initial commit first.

### CODE mode says the patch didn't apply and re-implements instead
That's the built-in fallback. Your working tree changed while the agents ran, or the diff touches files you edited since. Commit or stash first, then retry.

### The agents don't see my new file
CODE mode starts the agents from a snapshot of tracked files. Run `git add <file>` (it doesn't need to be committed) and retry.

### `Tab` doesn't change the mode
Your terminal or multiplexer may be intercepting it. Use `/mode fast`, `/mode ask`, or `/mode code` instead.

### Garbled boxes, missing spinner, or odd colours
Use a UTF-8 locale (`locale | grep UTF-8`), a font with Braille characters, and a terminal with true colour. kitty works well.

### It's slow
- Use FAST for simple tasks.
- Set `/quorum 2` (default) or `/quorum 1`.
- Use faster models for agents and a strong one only for the judge.
- Check the warm dot is green.
- Read the timing line under the result. If one agent or the judge dominates, that step's model is the bottleneck.
- Compare against `time opencode run "hi"`. If plain opencode is just as slow, the cause is your default model, not trio: set a faster one with `/model provider/fast-model`.
- Try `/warm off` to rule out the warm server.

### Leftover processes after a crash
```bash
pkill -f "opencode run"
pkill -f "opencode serve"
```

### Token usage is high
That's expected; see [Speed and cost](#speed-and-cost). Use FAST, lower the quorum, or pick cheaper models.

---

## Uninstall

```bash
./uninstall.sh
```

This removes `~/.local/bin/trio` only. To remove Textual on Arch: `sudo pacman -Rns python-textual`.

---

## Reporting bugs

Please include:

```bash
uname -a
python3 --version
opencode --version
pacman -Q python-textual     # or: python3 -m pip show textual
```

plus the mode you were in, the command you ran, and any traceback printed after trio exits.

---

## License

MIT. See [LICENSE](LICENSE).
