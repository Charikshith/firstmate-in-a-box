#!/usr/bin/env bash
# First-run bootstrap inside the firstmate box. Safe to rerun; never logs in for you.
#   fm-box-init            write config, check tools, print what is left to do by hand
#   fm-box-init --quiet    only write config (what the container entry runs on every start)
set -eu
export FM_HOME="${FM_HOME:-/home/node/fm-home}"
mkdir -p "$FM_HOME/config" "$FM_HOME/data" "$FM_HOME/state"
echo tmux > "$FM_HOME/config/backend"
[ "${1:-}" = --quiet ] && exit 0

echo "FM_HOME=$FM_HOME  backend=$(cat "$FM_HOME/config/backend")"
missing=0
for t in tmux git jq ps gh treehouse no-mistakes claude gh-axi tasks-axi quota-axi lavish-axi chrome-devtools-axi; do
  command -v "$t" >/dev/null || { echo "MISSING: $t (rebuild the image: docker build -f Dockerfile.firstmate -t agent-box-fm .)"; missing=1; }
done
# firstmate's own tool check; silent = all good, NEEDS_GH_AUTH is expected until gh login
"${FM_ROOT:-/opt/firstmate}/bin/fm-bootstrap.sh" || missing=1

echo
echo "Still to do by hand (this script does not log in for you):"
n=0
step() { n=$((n + 1)); echo "  $n. $1"; }
gh auth status >/dev/null 2>&1 || step "GitHub: docker exec -it firstmate-box gh auth login   (paste the fine-grained token; kept in the fm-gh volume). Then: gh auth setup-git"
git config --global user.email >/dev/null 2>&1 || step "git identity: docker exec firstmate-box git config --global user.name 'Your Name'  and  user.email you@example.com"
claude auth status >/dev/null 2>&1 || step "Claude login: docagent fm attach, then log in with your subscription in the first-mate window (kept in the agent-box-claude volume)"
step "One-time bypass-permissions prompt: workers run Claude with permissions bypassed; accept it once when it first appears in docagent fm attach (kept in the agent-box-claude volume)"
step "Bring your old data across (optional): scripts\fm-box-import-data.ps1 on Windows"
exit "$missing"
