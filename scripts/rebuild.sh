#!/bin/sh

~/nixos/scripts/sort-packages.sh
sudo nixos-rebuild switch --flake ~/nixos#chey
