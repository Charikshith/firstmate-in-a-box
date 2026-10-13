# docagent - run Claude Code or pi in the agent-box container from Windows PowerShell (no WSL).
# usage: docagent [cc|pi] [args...]      (cc = Claude Code, default)
#        docagent fm start|attach|stop|status|rm   (firstmate in one long-lived container, see docs/FIRSTMATE-IN-BOX.md)
# cc/pi: run it from a project folder under $env:AGENT_BOX_ROOT (default D:\Code).
param([Parameter(Position = 0)][string]$Tool = 'cc', [Parameter(ValueFromRemainingArguments)][string[]]$Rest)
$ErrorActionPreference = 'Stop'

if ($Tool -eq 'fm') {
    # Long-lived box: firstmate and every worker are tmux windows in one container.
    # FM_BOX_SUFFIX renames the container and every volume (e.g. '-test') so checks never touch the real ones.
    $ErrorActionPreference = 'Continue'   # Windows PowerShell 5.1 turns native stderr into a terminating error; we check $LASTEXITCODE instead
    $sfx = $env:FM_BOX_SUFFIX
    $name = "firstmate-box$sfx"
    $image = if ($env:AGENT_BOX_FM_IMAGE) { $env:AGENT_BOX_FM_IMAGE } else { 'agent-box-fm' }
    $port = if ($env:FM_BOX_PORT) { $env:FM_BOX_PORT } else { '4387' }
    $sub = if ($Rest) { $Rest[0] } else { 'status' }
    $state = docker ps -a --filter "name=^/$name`$" --format '{{.State}}'   # running, exited, created... or empty

    switch ($sub) {
        'start' {
            if ($state -eq 'running') { Write-Host "$name already running"; break }
            if ($state) { docker start $name | Out-Null }
            else {
                if (-not (docker images -q $image)) {
                    throw "docagent: image '$image' not found. Build it: docker build -t agent-box . ; docker build -f Dockerfile.firstmate -t $image ."
                }
                # Never pass ANTHROPIC_API_KEY (keeps Claude Code on the subscription). Port is published on 127.0.0.1 only.
                docker run -d --init --name $name --restart unless-stopped --stop-timeout 30 `
                    -v "fm-home${sfx}:/home/node/fm-home" `
                    -v "fm-projects${sfx}:/home/node/fm-home/projects" `
                    -v "agent-box-claude${sfx}:/home/node/.claude" `
                    -v "agent-box-pi${sfx}:/home/node/.pi" `
                    -v "fm-gh${sfx}:/home/node/.config/gh" `
                    -v "agent-box-pnpm${sfx}:/home/node/.pnpm-store" `
                    -v "agent-box-uv${sfx}:/home/node/.cache/uv" `
                    -e PNPM_STORE_DIR=/home/node/.pnpm-store `
                    -e UV_LINK_MODE=copy `
                    -e TERM=xterm-256color `
                    -p "127.0.0.1:${port}:4387" `
                    $image fm-box-entry | Out-Null
                if ($LASTEXITCODE) { throw "docagent: docker run failed (is port $port taken? set FM_BOX_PORT)" }
                $created = $true
            }
            for ($i = 0; $i -lt 30; $i++) {
                docker exec $name tmux has-session -t firstmate 2>$null
                if ($LASTEXITCODE -eq 0) { break }
                Start-Sleep -Seconds 1
            }
            Write-Host "$name running"
            if ($created) { docker exec $name fm-box-init }
        }
        'attach' {
            if ($state -ne 'running') { throw "docagent: $name is not running (docagent fm start)" }
            docker exec -it $name tmux attach -t firstmate
            exit $LASTEXITCODE
        }
        'stop' {
            if ($state -eq 'running') { docker stop -t 30 $name | Out-Null; Write-Host "$name stopped (data kept; stays stopped across reboots)" }
            else { Write-Host "$name not running" }
        }
        'status' {
            if (-not $state) { Write-Host "$name not created" }
            elseif ($state -ne 'running') { Write-Host "$name stopped" }
            else {
                Write-Host "$name running"
                docker exec $name tmux list-windows -t firstmate
            }
        }
        'rm' {
            if ($state -eq 'running') { throw "docagent: $name is running; stop it first (docagent fm stop). Volumes are never removed." }
            if ($state) { docker rm $name | Out-Null; Write-Host "$name removed (volumes kept)" }
            else { Write-Host "$name not created" }
        }
        default { throw "docagent: unknown fm command '$sub' (use start, attach, stop, status or rm)" }
    }
    exit 0
}

if ($Tool -notin 'cc', 'pi') { throw "docagent: unknown tool '$Tool' (use cc, pi or fm)" }
$cmd = if ($Tool -eq 'cc') { 'claude' } else { 'pi' }

$root = if ($env:AGENT_BOX_ROOT) { $env:AGENT_BOX_ROOT } else { 'D:\Code' }
$image = if ($env:AGENT_BOX_IMAGE) { $env:AGENT_BOX_IMAGE } else { 'agent-box' }
$root = (Resolve-Path $root).Path.TrimEnd('\')
$cwd = (Get-Location).Path
if (-not ($cwd + '\').StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "docagent: run from a folder under $root (set AGENT_BOX_ROOT to change)"
}
$rel = $cwd.Substring($root.Length).Replace('\', '/')

# Whole root mounted once at /code. Package caches live in named volumes (Linux disk, fast);
# the project is on the Windows disk, so installs copy rather than hard-link.
# Never pass ANTHROPIC_API_KEY: absence keeps Claude Code on the subscription.
docker run -it --rm `
    -v "${root}:/code" `
    -w "/code$rel" `
    -v agent-box-claude:/home/node/.claude `
    -v agent-box-pi:/home/node/.pi `
    -v agent-box-pnpm:/home/node/.pnpm-store `
    -v agent-box-uv:/home/node/.cache/uv `
    -e PNPM_STORE_DIR=/home/node/.pnpm-store `
    -e UV_LINK_MODE=copy `
    $image $cmd @Rest
exit $LASTEXITCODE
