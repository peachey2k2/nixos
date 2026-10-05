#!/usr/bin/env sh
# Opsec Mode: route all traffic through dalet (tailscale exit node).
# Used by the nilshell dashboard button. Exit code 0 on success, notify only on error.
set -eu

node="dalet"

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "opsec" "$1"
  fi
}

# Prints "enabled" only when an exit node is actually selected AND online.
# When no exit node is set, tailscale omits ExitNodeStatus (jq -> empty).
is_enabled() {
  tailscale status --json 2>/dev/null | jq -e '.ExitNodeStatus.Online == true' >/dev/null 2>&1
}

if [ "${1:-toggle}" = "status" ]; then
  if is_enabled; then
    echo enabled
  else
    echo disabled
  fi
  exit 0
fi

if is_enabled; then
  if tailscale set --exit-node= 2>/dev/null; then
    exit 0
  fi
  notify "Failed to disable opsec mode"
  exit 1
fi

if tailscale set --exit-node="$node" 2>/dev/null; then
  exit 0
fi

notify "Failed to enable opsec mode"
exit 1
