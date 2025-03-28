#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."
PACKAGES_FILE=$NIX_DIR/packages.nix

echo "pkgs: with pkgs; [
$(cat $PACKAGES_FILE | grep "^[[:space:]]" | sort)
]" > $PACKAGES_FILE

