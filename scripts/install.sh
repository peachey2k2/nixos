#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."

echo ">> generating hardware-configuration.nix..."
nixos-generate-config --show-hardware-config > "$NIX_DIR"/hardware-configuration.nix

echo ">> rebuilding system..."
nixos-rebuild switch --flake "$NIX_DIR"#chey

echo ">> done!"
