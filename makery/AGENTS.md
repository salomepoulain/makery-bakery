# The makery kitchen (for agents)

This `.makery/` folder belongs to [makery-bakery](https://github.com/salomepoulain/makery-bakery).
It holds the setup this project shares with other projects. It is gitignored and never goes to
GitHub. The human works with it through the `bake` command.

## What's in here

- `headchef/`: the orchestrator. It hires and fires stations and runs the core commands.
- `stations/<name>/`: one folder per station in this project. `_empty_station` is the template
  for new ones and is never used directly. A fresh project has no other stations yet.
- `menu.mk`: the entry point `bake` calls.

A station looks like this:

| Path | What it does |
|---|---|
| `menu.mk` | the station's commands |
| `cook/skills/*.sh` | the scripts behind those commands |
| `cook/contract/hired.sh` | runs once when the station is hired (`bake first <name>`) |
| `cook/contract/fired.sh` | runs once when it's fired (`bake burnt <name>`) |
| `cook/contract/illegal.sh` | optional, runs after `bake shady` |
| `workbench/.tools` | system commands that must exist before hiring |
| `workbench/.countertop` | lines that go into `.gitignore` |
| `workbench/.dishsoap` | junk that `bake germs` deletes (bash globs from the project root) |
| `workbench/.contraband` | paths that `bake shady` moves into the stash |
| `workbench/pantry/` | files `hired.sh` copies into the project |

## Use it

If a station already has a command for something, run that command instead of doing it by hand.
Plain `bake` shows the Head Chef's menu and every station's menu.

```sh
bake <station> <command>   # run one of a station's commands
bake germs                 # delete everything the stations list in .dishsoap
```

`__stash__` and the symlinks pointing into it are on purpose. `bake shady` moved those files to a
synced folder outside the repo. Don't replace the links with real files or delete them, even when
they look broken: the drive with the stash may just not be plugged in.

## Never run these yourself

Station commands are scripts that run with the human's own permissions. A rule like "no
`git push`" doesn't stop a bake command that pushes inside its script. So: if you aren't allowed
to do something directly, don't do it through a bake command either.

- `bake all` and `bake burnt` delete files. They refuse without a real terminal. Never get around
  that, so no `echo y |`, no `script`, no faked terminal.
- `bake request`, `bake in` and `bake release` send, merge or publish things other people see.
- `bake first`, `bake update` and `bake shady` install software or move files. `bake first` runs
  the station's `hired.sh`, which can do anything. Only run these when the human asks for it in
  this conversation.
- Station commands that push, publish, merge or delete, like a commit-and-push command or one
  that makes a repo public. Read the script in `cook/skills/` if you're unsure what a command does.

## Don't edit the kitchen to change behaviour

- `headchef/` is overwritten when makery-bakery updates. A change to it goes as a pull request to
  makery-bakery.
- A station here is a copy from the registry (`MAKERY_REGISTRY`, by default
  `salomepoulain/makery-stations`). To change one, edit it in `.makery/stations/<name>/` and let
  the human send it with `bake request`. Never run `bake request` yourself: it opens a pull
  request on the registry.

## Creating or changing a station

- Start a new one with `bake station <name>`. It copies the `_empty_station` template into
  `.makery/stations/<name>/`.
- In `menu.mk`, every command is a target that runs a script in `cook/skills/`. Add an `ITEM`
  line for it in the `menu::` target so it shows up in `bake`. Copy the template's pattern.
- `hired.sh`, `fired.sh` and `illegal.sh` are run by the Head Chef, not menu commands. Delete
  `illegal.sh` if nothing needs to happen after `bake shady`.
- Everything in `.contraband` must also be in `.countertop`, or a stash symlink ends up in git.
- `.dishsoap` lines are bash globs from the project root. `__pycache__` only matches at the
  root, `**/__pycache__` matches at any depth, and `**` skips hidden folders, so name those
  explicitly (`.claude/**/__pycache__`).
- `.tools` lists only system commands every machine needs. Hiring stops if one is missing.
- `hired.sh` runs on every `bake first`, on other people's machines too. Keep it to setting up
  this project, and say what it installs.
- A command that pushes, publishes, merges or deletes should refuse without a person at the
  keyboard: start its script with `if [ ! -t 0 ] || [ ! -t 1 ]; then SAY "This needs a person
  at a real terminal."; exit 1; fi`.
- Try it with `bake first <name>` (runs `hired.sh`; a station that's only local gets hired as
  it is) and `bake <name> <command>`. If the registry also has a station by that name,
  `bake first` offers to replace the local copy with it, so answer no to keep your changes.

## Suggest, don't decide

Two things are worth pointing out when you see them. For both: suggest it once, at the end of a
task, not in the middle of the work. If the human says no, don't bring it up again.

**A new station command.** Watch for setup that isn't really about this project: a conda
environment, a LaTeX build, a cluster job script, the same `.gitignore` lines again. Suggest
turning it into a station command, so the next project gets it with `bake first <name>` instead
of copy-paste. Name the station (an existing one or a new one) and the command. Only build it
when the human says yes, and then only in `.makery/stations/<name>/` of this project. Sending it
to the registry is the human's `bake request`.

**Going shady.** Suggest `bake shady <path>` for something that is untracked and should follow the
human to another machine without going to GitHub. For example a large dataset, model checkpoints
or experiment results that are slow to regenerate, or personal files like `.env` or notes. Say
what you noticed and why it fits, e.g. "`data/` is 12 GB, untracked and slow to rebuild, so
`bake shady data` would keep it out of the repo and sync it through your `.shadow/` folder."
Don't suggest it for caches (those belong in `.dishsoap`), for `.venv` or other environments
(they only work on the machine that built them), or for anything that belongs in git. Let the
human run it.
