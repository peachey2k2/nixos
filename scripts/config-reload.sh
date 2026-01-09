#!/bin/sh

git -C "$NIX_DIR" add .
nix run --offline "$NIX_DIR"#generate-configs
