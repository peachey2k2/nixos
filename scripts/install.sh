#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."

echo ">> generating hardware-configuration.nix..."
sudo nixos-generate-config --show-hardware-config > "$NIX_DIR"/hardware-configuration.nix

if [[ "$result" -ne "0" ]]; then
  exit 1
fi

echo ">> rebuilding system..."
# using `boot` instead of `switch` cuz otherwise it just nukes the current system
sudo nixos-rebuild boot --accept-flake-config --flake "$NIX_DIR"#chey

if [[ "$result" -ne "0" ]]; then
  exit 1
fi

echo ">> generating configs..."
nix run "$NIX_DIR"#generate-configs


if [[ "$result" -ne "0" ]]; then
  exit 1
fi

echo ">> done!"
