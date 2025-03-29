#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."
PACKAGES_FILE=$NIX_DIR/packages.nix
LOG_FILE=$NIX_DIR/log.txt

log () {
  echo $(date +"%d-%m-%Y %H:%M") [PKG-SORT] "$1" >> "$LOG_FILE"
}

sort_pkgs () {
  echo \
    "pkgs: with pkgs; [" \
    $(cat $PACKAGES_FILE | grep "^[[:space:]]" | sort) \
    "]" \
  > $PACKAGES_FILE
}

if [[ sort_pkgs ]]; then
  log "sort successful"
else
  log "sort failed. error code: $?"
fi

