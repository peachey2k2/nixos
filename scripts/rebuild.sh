#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."
LOG_FILE=$NIX_DIR/log.txt

log () {
  echo $(date +"%d-%m-%Y %H:%M") [REBUILD] $1 >> "$LOG_FILE"
}

git -C "$NIX_DIR" add .
"$NIX_DIR"/scripts/sort-packages.sh

tac "$NIX_DIR/log.txt" | grep -q -m 1 "$(date +"%d-%m-%Y") ..:.. \[REBUILD\] recreated flake\.lock"
updated_today="$?"

if [[ "$updated_today" -eq "0" ]]; then
  nh os switch "$NIX_DIR" -H chey --accept-flake-config
else
  nh os switch "$NIX_DIR" -H chey --update --accept-flake-config
fi

"$NIX_DIR"/scripts/sort-packages.sh

result="$?"

if [[ "$result" -eq "0" ]]; then
  if [[ "$updated_today" -ne "0" ]]; then
    log "recreated flake.lock"
  fi

  log "rebuild successful"
else
  log "failed to rebuild"
fi
