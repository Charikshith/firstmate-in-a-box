# Copy firstmate's data\ folder (backlog, captain.md, learnings.md, projects.md, briefs...) into the firstmate box's
# fm-home volume. state\ is left behind on purpose: it is runtime state of tmux windows and worktrees that no longer exist.
# usage: fm-box-import-data.ps1 -Source <path to your firstmate data dir> [-Force] [-WhatIf]
#   -WhatIf  dry run: report what would be copied and whether it would refuse, change nothing
#   -Force   copy into a box whose data\ is not empty (same-named files are overwritten, other files stay)
# The box must be running (docagent fm start). FM_BOX_SUFFIX renames the box like docagent does.
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$Source, [switch]$Force)
$ErrorActionPreference = 'Continue'   # Windows PowerShell 5.1 turns native stderr into a terminating error; we check $LASTEXITCODE instead

$name = "firstmate-box$($env:FM_BOX_SUFFIX)"
$dest = '/home/node/fm-home/data'
if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "fm-box-import-data: no such folder: $Source" }
$Source = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
if ((docker ps --filter "name=^/$name`$" --format '{{.State}}') -ne 'running') { throw "fm-box-import-data: $name is not running (docagent fm start)" }

$existing = @(docker exec $name ls -A $dest)
if ($existing.Count -gt 0 -and -not $Force) {
    throw "fm-box-import-data: $name already has data in $dest ($($existing -join ', ')); nothing copied. Use -Force to copy over it."
}

$files = @(Get-ChildItem -LiteralPath $Source -Recurse -File)
if ($PSCmdlet.ShouldProcess("${name}:$dest", "copy $($files.Count) files from $Source (state\ is not copied)")) {
    docker cp "$Source\." "${name}:$dest"
    if ($LASTEXITCODE) { throw 'fm-box-import-data: docker cp failed' }
    docker exec -u root $name chown -R node:node $dest   # docker cp creates root-owned files
    if ($LASTEXITCODE) { throw 'fm-box-import-data: chown failed' }
    Write-Host "copied $($files.Count) files into ${name}:$dest. Projects are not copied: firstmate re-clones them into the fm-projects volume."
}
