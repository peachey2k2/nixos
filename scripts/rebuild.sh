#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."

git -C "$NIX_DIR" add .
~/nixos/scripts/sort-packages.sh
# sudo nixos-rebuild switch --flake ~/nixos#chey
nh os switch /home/pe/nixos -H chey
