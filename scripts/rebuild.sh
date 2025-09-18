#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."
LOG_FILE=$NIX_DIR/log.txt

log () {
  echo $(date +"%d-%m-%Y %H:%M") [REBUILD] $1 >> "$LOG_FILE"
}

updated_today() {
  tac nixos/log.txt | grep -q -m 1 "$(date +"%d-%m-%Y") ..:.. \[REBUILD\] rebuild successful"
}

git -C "$NIX_DIR" add .
~/nixos/scripts/sort-packages.sh
# sudo nixos-rebuild switch --flake ~/nixos#chey

if updated_today; then
  nh os switch /home/pe/nixos -H chey
else
  nh os switch /home/pe/nixos -H chey --update
fi


if [[ "$?" -eq "0" ]]; then
  log "rebuild successful"
else
  log "failed to rebuild"
fi
