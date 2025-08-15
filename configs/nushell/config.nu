# config.nu
#
# Installed by:
# version = "0.104.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# This file is loaded after env.nu and before login.nu
#
# You can open this file in your default editor using:
# config nu
#
# See `help config nu` for more options
#
# You can remove these comments if you want or leave
# them for future reference.

$env.NIX_SHELL_DEPTH = $env.NIX_SHELL_DEPTH? | default 0
$env.SHELL_DEPTH = $env.SHELL_DEPTH? | default 0
$env.config.show_banner = false


mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

alias "core-nu" = nu
alias "nu" = core-nu -e $"$env.SHELL_DEPTH = (($env.SHELL_DEPTH | into int) + 1)"

alias "core-nix-develop" = nix develop
alias "nix develop" = core-nix-develop --command nu -e $"$env.SHELL_DEPTH = (($env.SHELL_DEPTH | into int) + 1); $env.NIX_SHELL_DEPTH = (($env.NIX_SHELL_DEPTH | into int) + 1)"


alias "%clear-backups" = ~/nixos/scripts/clear-backups.sh
alias "%config-reload" = ~/nixos/scripts/config-reload.sh
alias "%edit" = hx ~/nixos/flake.nix -w ~/nixos
alias "%list-packages" = nix-store -q --requisites /run/current-system/sw | fzf
alias "%logs" = tail ~/nixos/log.txt
alias "%rebuild" = ~/nixos/scripts/rebuild.sh

def "%devel" [] {
  let proj = try {
    ls ~/development | where type == "dir" | get name | input list -f
  } catch { return }
  if ($"($proj)/flake.nix" | path exists) {
    core-nix-develop $proj --command nu -e $"cd ($proj); $env.SHELL_DEPTH = (($env.SHELL_DEPTH | into int) + 1); $env.NIX_SHELL_DEPTH = (($env.NIX_SHELL_DEPTH | into int) + 1)"
  } else {
    cd $proj
    nu
  }
}

if not ("DISPLAY" in $env) and (tty) == "/dev/tty1" {
  exec Hyprland
}
