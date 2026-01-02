#!/bin/sh

PACKAGES_FILE=$NIX_DIR/packages.nix
LOG_FILE=$NIX_DIR/log.txt

log () {
  echo $(date +"%d-%m-%Y %H:%M") [PKG-SORT] "$1" >> "$LOG_FILE"
}

sort_pkgs () {
  echo "pkgs: with pkgs; ["
  echo "$(cat $PACKAGES_FILE | grep "^[[:space:]]" | sort)"
  echo "]"
}

x=$(sort_pkgs)
if printf "$x" > $PACKAGES_FILE; then
  log "sort successful"
else
  log "sort failed. error code: $?"
fi

