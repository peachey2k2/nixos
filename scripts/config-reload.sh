#!/bin/sh

NIX_DIR="$(cd $(dirname $0) && pwd)/.."

git -C "$NIX_DIR" add .
nix run ~/nixos#generate-configs
