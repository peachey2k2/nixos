#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."

echo ">> generating hardware-configuration.nix..."
sudo nixos-generate-config --show-hardware-config > "$NIX_DIR"/hardware-configuration.nix

echo ">> rebuilding system..."
sudo nixos-rebuild switch --flake "$NIX_DIR"#chey

echo ">> done!"
