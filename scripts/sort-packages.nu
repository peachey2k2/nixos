#!/usr/bin/env nu

let pkgs_file = $env.NIX_DIR/packages.nix
let log_file = $env.NIX_DIR/log.txt

def log [text: string] {
  (
    (date now | format date "%d-%m-%Y %H:%M ")
    ++ "[PKG-SORT] "
    ++ $text
    ++ "\n"
  ) | save -a $log_file
}

def sort_pkgs [] {[]
  echo "pkgs: with pkgs; ["
  echo "$(cat $PACKAGES_FILE | grep "^[[:space:]]" | sort)"
  echo "]"
}

x=$(sort_pkgs)
if printf "$x" > $PACKAGES_FILE; then
  log "sort successful"
else
  log "sort failed. error code: $?"
fi

