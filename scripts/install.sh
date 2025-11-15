#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."

echo ">> generating hardware-configuration.nix..."
sudo nixos-generate-config --show-hardware-config > "$NIX_DIR"/hardware-configuration.nix

echo ">> rebuilding system..."
# using `boot` instead of `switch` cuz otherwise it just nukes the current system
sudo nixos-rebuild boot --flake "$NIX_DIR"#chey

echo ">> done!"
