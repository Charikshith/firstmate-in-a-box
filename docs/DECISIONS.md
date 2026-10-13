# Decisions

Extract from the agent-box `docs/DECISIONS.md` (branch `fm/agent-box-fm-image`): the firstmate-in-a-box section only.

## Firstmate in the box (2026-10-13)

Phases and commands: [FIRSTMATE-IN-BOX.md](FIRSTMATE-IN-BOX.md).

- **One long-lived container** (`firstmate-box`, `--restart unless-stopped`), built `FROM agent-box` (`Dockerfile.firstmate`). Firstmate is built for Linux and runs everything as tmux windows, so the first mate and every worker live in that one box. `docagent cc` and `docagent pi` are unchanged; the existing `Dockerfile` is untouched.
- **Projects in a Docker volume** (`fm-projects`, mounted at `$FM_HOME/projects`), not bind-mounted from `D:\Code`. Worktrees and the package caches share one Linux filesystem (the hard-link saving above). Cost: no direct access to the files from Windows tools.
- **GitHub token in a Docker volume** (`fm-gh`), fine-grained, put there by `gh auth login`. Nothing secret is in the repo or the image. It is plain text in the volume (no keyring).
- **Port 4387 published on `127.0.0.1` only.** lavish-axi refuses a wildcard bind, so the entry script binds it to the container IP and prints links as `127.0.0.1`.
- **Everything firstmate writes lives in volumes.** `fm-home` also holds `.gitconfig`, the treehouse worktree pool and the no-mistakes database (via `GIT_CONFIG_GLOBAL`, `TREEHOUSE_ROOT`, `NM_HOME`), so `docagent fm rm` loses nothing.
- **Stop is real.** Detached container: closing the terminal leaves it running. `stop` ends all processes (tmux, agents) and keeps data. With `--restart unless-stopped` an explicitly stopped container is not restarted by a Docker or machine restart; a running one is. Checked with a Docker Desktop restart.
- **Chromium skipped**: `fm-bootstrap.sh` only checks that `chrome-devtools-axi` exists, so a missing browser is not a blocker.
- **Pins**: gh 2.102.0, treehouse 3.1.3, no-mistakes 1.84.0 (linux-amd64 tarballs, sha256 checked), gh-axi 0.1.39, tasks-axi 0.2.6, quota-axi 0.1.61, lavish-axi 0.1.87, chrome-devtools-axi 0.1.41, firstmate fork `13a6744` (main, 2026-10-13). amd64 only. apt packages are not version-pinned, same as the base Dockerfile.
- **Line endings**: `.gitattributes` makes `Dockerfile*` and `*.sh` LF so nothing that runs in Linux is CRLF.

### Firstmate box: verified (2026-10-13, Docker Desktop 29.8.2)

- Image builds. `tmux 3.3a`, `gh 2.102.0`, `treehouse v3.1.3`, `no-mistakes v1.84.0`, `jq 1.6` and all five axi tools run in it, as uid 1000. `fm-bootstrap.sh` on a fresh home reports only `NEEDS_GH_AUTH`.
- `docagent cc --version` and `docagent pi --version` still run through `docker run` (2.1.296, 0.73.1).
- `fm start` (twice: idempotent), `status`, `attach` (real console: client attached, detach leaves the session running), `stop` (twice), `rm` (twice; refuses while running) and `start` after `rm` all work; volumes and their files survive each step.
- A box started from a PowerShell window that was then killed kept running.
- Docker Desktop restart: the running box came back, the explicitly stopped box stayed stopped.
- lavish-axi inside the box answers on the published `127.0.0.1` port.
- Import script: `-WhatIf` copies nothing, a non-empty `data\` is refused without `-Force`, only `data\` is copied (not `state\`), and the files end up owned by `node`.

### Firstmate box: not yet verified

- The three logins (GitHub, Claude, bypass prompt) need a human. Not tried either: an authenticated first-mate session, a real task, workers as tmux windows, treehouse and no-mistakes doing real work in the box, firstmate reconciling after a stop and start.
- Importing the repo author's real data, and whether its briefs (Windows paths) are useful in the box.
- A real Windows reboot (only a Docker Desktop restart was tried); Docker Desktop must be set to start at sign-in.
- Browser tooling (no Chromium), arm64, network allowlist.
- `docker stop` kills the agents; whether work in flight is lost depends on firstmate's reconciliation.
- A lavish-axi on the Windows host already holds port 4387; use `FM_BOX_PORT` or stop it.

