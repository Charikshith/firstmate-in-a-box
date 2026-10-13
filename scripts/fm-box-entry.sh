#!/usr/bin/env bash
# PID 1 of firstmate-box: start the first mate in tmux, then stay alive until `docker stop`.
# Runs again on every container (re)start, so the first-mate window comes back after a Docker restart or reboot.
set -eu
fm-box-init --quiet
# lavish only binds loopback or one concrete address (wildcards are refused): bind the container IP so the
# port published on the host's 127.0.0.1 reaches it, and print links as 127.0.0.1 so they open on Windows.
ip=$(hostname -i 2>/dev/null | cut -d' ' -f1 || true)
[ -z "$ip" ] || export LAVISH_AXI_HOST="$ip"
export LAVISH_AXI_LINK_HOST=127.0.0.1
tmux has-session -t firstmate 2>/dev/null \
  || tmux new-session -d -s firstmate -n firstmate -c /opt/firstmate 'claude; exec bash'
# docker stop sends TERM: hang the panes up cleanly (claude exits) before the container goes
trap 'tmux kill-server 2>/dev/null; exit 0' TERM INT
sleep infinity &
wait
