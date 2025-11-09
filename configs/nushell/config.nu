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

$env.EDITOR = "@editor@"
$env.VISUAL = "@editor@"

# default `rm` to send to trash instead of deleting. `-p` bypasses.
$env.config.rm.always_trash = true

# basic vim bindings for commands
$env.config.edit_mode = "vi"

# make the cursor look sane
$env.config.cursor_shape.vi_insert = "line"
$env.config.cursor_shape.vi_normal = "block"

# completion thingy
$env.CARAPACE_BRIDGES = "inshellisense,carapace,zsh,fish,bash"

$env.config.use_kitty_protocol = true

def "__init" [] {
  # show disk usage when the shell is opened
  if $env.SHELL_DEPTH == "0" {
    sys disks
      | select mount total free
      | each { |e|
        mut e = $e
        $e.usage = (100 * (1 - $e.free / $e.total) | into string -d 2) + "%";
        $e }
      | print
  }
}

mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

alias "cal" = cal --week-start "mo"

alias "core-nu" = nu
alias "nu" = core-nu -e $"$env.SHELL_DEPTH = (($env.SHELL_DEPTH | into int) + 1)"

alias "core-nix-develop" = nix develop

def --wrapped "nix develop" [...args] {
  core-nix-develop ...$args --command nu -e $"
    $env.SHELL_DEPTH = (($env.SHELL_DEPTH | into int) + 1);
    $env.NIX_SHELL_DEPTH = (($env.NIX_SHELL_DEPTH | into int) + 1)
  "
}

alias duf = duf --only-mp /,/boot --output mountpoint,size,used,avail,usage

alias "%clear-backups" = ~/nixos/scripts/clear-backups.sh
alias "%config-reload" = ~/nixos/scripts/config-reload.sh
alias "%edit"          = hx ~/nixos/flake.nix -w ~/nixos
alias "%list-packages" = nix-store -q --requisites /run/current-system/sw # temp fix
alias "%logs"          = tail ~/nixos/log.txt
alias "%rebuild"       = ~/nixos/scripts/rebuild.sh

def "%env" [...pkgs] { nix shell ...$pkgs --command nu -e $"
  $env.SHELL_DEPTH = (($env.SHELL_DEPTH | into int) + 1);
  $env.NIX_SHELL_DEPTH = (($env.NIX_SHELL_DEPTH | into int) + 1)" 
}

def "%devel" [] {
  let proj = try {
    (ls ~/development) ++ (ls ~/git) | where type == "dir" | get name | input list -f
  } catch { return }
  if ($"($proj)/flake.nix" | path exists) {
    core-nix-develop $proj --command nu -e $"
      cd ($proj);
      $env.SHELL_DEPTH = (($env.SHELL_DEPTH | into int) + 1);
      $env.NIX_SHELL_DEPTH = (($env.NIX_SHELL_DEPTH | into int) + 1)"
  } else {
    cd $proj
    nu
  }
}

$env.config.keybindings ++= [{
  name: unfreeze
  modifier: control
  keycode: char_z
  mode: emacs
  event: {
    send: executehostcommand,
    cmd: "job unfreeze"
  }
}]

if not ("DISPLAY" in $env) and (tty) == "/dev/tty1" {
  exec Hyprland
}
