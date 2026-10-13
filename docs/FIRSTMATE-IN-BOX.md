# Firstmate in the box

Run [firstmate](https://github.com/Charikshith/firstmate) (a supervisor that runs a crew of coding agents) in Docker on Windows, no WSL. One long-lived Linux container, `firstmate-box`, built on the agent-box image. The first mate and every worker are tmux windows in it. Decisions and what is not yet verified: [DECISIONS.md](DECISIONS.md).

## Phases

1. **Image** (done). `Dockerfile.firstmate` adds tmux, jq, procps, bash, unzip, gh, treehouse, no-mistakes, the five `*-axi` tools and the firstmate checkout (`/opt/firstmate`, pinned commit) to `agent-box`. All versions are pinned in the file.
   ```powershell
   docker build -t agent-box D:\Code\agent-box
   docker build -f Dockerfile.firstmate -t agent-box-fm D:\Code\agent-box
   ```
2. **Long-lived container** (done). `docagent fm ...` (below).
3. **First-run bootstrap** (script done, logins are yours). `fm-box-init` runs inside the box: sets `FM_HOME`, writes `config/backend` = `tmux`, checks the tools, runs firstmate's own `fm-bootstrap.sh`, and prints what is left. `docagent fm start` runs it after creating the box; rerun any time: `docker exec firstmate-box fm-box-init`.
4. **Bring old state across** (script done, not run on real data). `scripts\fm-box-import-data.ps1` copies firstmate's `data\` folder into the box. `state\` is left behind on purpose.

## Commands

| Command | What it does |
|---|---|
| `docagent fm start` | Create and start the box (or start a stopped one). Idempotent. Starts `claude` in tmux session `firstmate` |
| `docagent fm attach` | `docker exec -it` into that tmux session. `Ctrl-b d` detaches and leaves it running |
| `docagent fm status` | `running` / `stopped` / `not created`, plus the tmux windows |
| `docagent fm stop` | `docker stop` (30 s grace). Everything running in the box ends; all data is kept |
| `docagent fm rm` | Remove the stopped container. Never removes a volume |

Environment: `FM_BOX_PORT` (host port, default 4387), `FM_BOX_SUFFIX` (appended to the container and every volume name; used for tests), `AGENT_BOX_FM_IMAGE` (default `agent-box-fm`).

## What you do by hand

`fm-box-init` prints only the steps that are still open. It never logs in for you.

1. **GitHub**: `docker exec -it firstmate-box gh auth login`, paste a fine-grained token (kept in the `fm-gh` volume as plain text; there is no keyring in the container), then `gh auth setup-git`.
2. **Git identity**: `docker exec firstmate-box git config --global user.name "..."` and `user.email`. Stored in the `fm-home` volume.
3. **Claude login**: `docagent fm attach`, log in with your subscription in the first-mate window. Shares the `agent-box-claude` volume with `docagent cc`, so an existing login is reused.
4. **Bypass-permissions prompt**: workers run Claude with permissions bypassed. Accept the one-time prompt when it first appears.
5. **Import data** (optional): `scripts\fm-box-import-data.ps1 -Source <your firstmate data dir> -WhatIf` first, then without `-WhatIf`. Refuses a box whose `data\` is not empty unless `-Force`.
6. **First project**: ask the first mate to add it. It clones into the `fm-projects` volume, not from `D:\Code`.

## Stop, restart, reboot

- Closing the terminal leaves the box running (it is a detached container; tested).
- `docagent fm stop` ends every process in the box (first mate, workers, tmux) but keeps the container filesystem and all volumes. The next `start` relaunches the first mate, which reconciles from `FM_HOME` on disk.
- The container uses `--restart unless-stopped`. Docker's rule: it restarts after a Docker restart or reboot unless you stopped it explicitly. Checked on this machine with a Docker Desktop restart: a running box came back, an explicitly stopped box stayed stopped.
- That only works while Docker Desktop itself is running. Turn on "Start Docker Desktop when you sign in" if you want the box back after a reboot.

## Chromium

Not installed. `fm-bootstrap.sh` only checks that the `chrome-devtools-axi` command exists (verified: with it installed and no browser, bootstrap reports only `NEEDS_GH_AUTH`). Browser actions by the crew in the box will fail. Add Chromium to `Dockerfile.firstmate` if you need them.

## Port 4387

lavish-axi (review pages) listens on 4387 in the box, published to `127.0.0.1` only. A lavish-axi running on Windows also uses 4387: stop it or set `FM_BOX_PORT` (links printed in the box say 4387, so use the same port to click them).
