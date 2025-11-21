#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."
LOG_FILE=$NIX_DIR/log.txt

log () {
  echo $(date +"%d-%m-%Y %H:%M") [REBUILD] $1 >> "$LOG_FILE"
}

git -C "$NIX_DIR" add .
~/nixos/scripts/sort-packages.sh
# sudo nixos-rebuild switch --flake ~/nixos#chey

tac "$NIX_DIR/log.txt" | grep -q -m 1 "$(date +"%d-%m-%Y") ..:.. \[REBUILD\] recreated flake\.lock"
updated_today="$?"

if [[ "$updated_today" -eq "0" ]]; then
  nh os switch /home/pe/nixos -H chey --accept-flake-config
else
  nh os switch /home/pe/nixos -H chey --update --accept-flake-config
fi

result="$?"

if [[ "$updated_today" -ne "0" ]]; then
  log "recreated flake.lock"
fi

if [[ "$result" -eq "0" ]]; then
  log "rebuild successful"
else
  log "failed to rebuild"
fi
