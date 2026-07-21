#!/usr/bin/env sh
set -eu

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/nilshell"
pidfile="$state_dir/lid-sleep-inhibit.pid"
mkdir -p "$state_dir"

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "nilshell" "$1"
  fi
}

is_inhibited() {
  [ -f "$pidfile" ] || return 1
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

if [ "${1:-toggle}" = "status" ]; then
  if is_inhibited; then
    echo disabled
  else
    rm -f "$pidfile"
    echo enabled
  fi
  exit 0
fi

if [ -f "$pidfile" ]; then
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    rm -f "$pidfile"
    notify "Sleep on lid close enabled"
    exit 0
  fi
  rm -f "$pidfile"
fi

systemd-inhibit \
  --what=handle-lid-switch \
  --who=nilshell \
  --why="User toggled sleep on lid close off from nilshell dashboard" \
  --mode=block \
  sh -c 'echo "$$" > "$1"; exec sleep infinity' sh "$pidfile" &
inhibitor_pid="$!"

# Wait for the inhibitor child to write its pid before returning. Without this,
# the dashboard can refresh its state before the lock exists and flip back to
# "enabled" even though the inhibitor starts a moment later.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if is_inhibited; then
    notify "Sleep on lid close disabled"
    exit 0
  fi
  sleep 0.05
done

kill "$inhibitor_pid" 2>/dev/null || true
rm -f "$pidfile"
notify "Failed to disable sleep on lid close"
exit 1
