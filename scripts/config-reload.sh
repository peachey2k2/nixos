#!/bin/sh

git -C "$NIX_DIR" add .
nix run "$NIX_DIR"#generate-configs
