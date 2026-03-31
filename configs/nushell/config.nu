use std/clip

$env.NIX_SHELL_DEPTH = $env.NIX_SHELL_DEPTH? | default 0
$env.SHELL_DEPTH = $env.SHELL_DEPTH? | default 0
$env.config.show_banner = false

$env.EDITOR = "@editor@"
$env.VISUAL = "@editor@"
$env.SHELL = (^which nu)

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
$env.config.display_errors.exit_code = true
$env.config.display_errors.termination_signal = true

# give the tables a lil bit of that swag
$env.config.table.mode = "light"
$env.config.table.index_mode = "auto"
$env.config.table.padding = {left:0, right:1} # 1 space is too little and 3 is too much
$env.config.table.trim.methodology = "truncating"
$env.config.table.trim.truncating_suffix = "…" # save space for +2 characters
$env.config.table.missing_value_symbol = $"(ansi red)(ansi reset)"

$env.config.datetime_format.table = null
$env.config.datetime_format.normal = $"(ansi blue_bold)%d(ansi reset)(ansi yellow)/(ansi blue_bold)%m(ansi reset)(ansi yellow)/(ansi blue_bold)%Y(ansi reset) (ansi magenta_bold)%H(ansi reset)(ansi yellow):(ansi magenta_bold)%M(ansi reset)(ansi yellow):(ansi magenta_bold)%S(ansi reset)"

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

alias duf = duf --only-mp /,/home --output mountpoint,size,avail,usage

alias "%clear-backups" = /home/pe/nixos/scripts/clear-backups.sh          # clear all .backup files to prevent conflicts on config replaces
alias "%config-reload" = /home/pe/nixos/scripts/config-reload.sh          # rebuild all config files in nixos/configs
alias "%edit"          = hx /home/pe/nixos/flake.nix -w /home/pe/nixos    # edit the system flake
alias "%list"          = nix-store -q --requisites /run/current-system/sw # list all store paths for the current system derivation
alias "%logs"          = tail /home/pe/nixos/log.txt                      # calls `tail` on script logs
alias "%rebuild"       = /home/pe/nixos/scripts/rebuild.sh                # rebuild the system derivation

# its the fortify warning bullshit on -o0
# ~@amaanq
$env.NIX_HARDENING_ENABLE = ($env.NIX_HARDENING_ENABLE? | default '' | split row ' ' | where { $in !~ 'fortify' } | str join ' ') 

def --wrapped run0 [...rest] {
  (^run0
    --setenv=TERMINFO=($env.TERMINFO?)
    --setenv=STARSHIP_CONFIG=($env.HOME)/.config/starship.toml
    ...$rest)
}

def --wrapped sudo [...rest] {
  print "use run0 instead!!!!"
  run0 ...$rest
}

def --wrapped "%env" [...rest] {
  NIXPKGS_ALLOW_UNFREE=1 NIXPKGS_ALLOW_INSECURE=1 nix shell --impure ...(
    $rest | each {|x|
      if not (
        ($x | str contains "#") or
        ($x | str starts-with "-")
      ) {
        "nixpkgs#" ++ $x
      } else {
        $x
      }
    }
  ) --command nu -e $"
    $env.SHELL_DEPTH = (($env.SHELL_DEPTH | into int) + 1);
    $env.NIX_SHELL_DEPTH = (($env.NIX_SHELL_DEPTH | into int) + 1)";
}

def "%devel" [...rest] {
  let proj = try {
    (ls /home/pe/development) ++ (ls /home/pe/git) | where type == "dir" | get name | input list -f
  } catch { return }
  if (
    ($"($proj)/flake.nix" | path exists) and
    not (nix flake show $proj --quiet --json e> /dev/null | from json | get -o inventory.devShells.output.children.x86_64-linux | is-empty)
    ) {
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
  mode: [emacs, vi_insert, vi_normal]
  event: {
    send: executehostcommand,
    cmd: "job unfreeze"
  }
}]

# `nu-highlight` with default colors
#
# Custom themes can produce a lot more ansi color codes and make the output
# exceed discord's character limits
def nu-highlight-default [] {
  let input = $in
  $env.config.color_config = {}
  $input | nu-highlight
}

# Copy the current commandline, add syntax highlighting, wrap it in a
# markdown code block, copy that to the system clipboard.
#
# Perfect for sharing code snippets on Discord.
def "nu-keybind commandline-copy" []: nothing -> nothing {
  commandline
  | nu-highlight-default
  | [
    "```ansi"
    $in
    "```"
  ]
  | str join (char nl)
  | clip copy --ansi
}

def --env y [...args] {
  let tmp = (mktemp -t "yazi-cwd.XXXXXX")
  ^yazi ...$args --cwd-file $tmp
  let cwd = (open $tmp)
  if $cwd != $env.PWD and ($cwd | path exists) {
    cd $cwd
  }
  rm -fp $tmp
}

$env.config.keybindings ++= [
  {
    name: copy_color_commandline
    modifier: control_alt
    keycode: char_c
    mode: [ emacs vi_insert vi_normal ]
    event: {
      send: executehostcommand
      cmd: 'nu-keybind commandline-copy'
    }
  }
]

$env.RUST_BACKTRACE = 1


if not ("DISPLAY" in $env) and (tty) == "/dev/tty1" {
  try {
    nvidia-smi --query-gpu=name --format=csv,noheader o+e> /dev/null
    $env.NVIDIA_GPU_ENABLED = "1"
  } catch {}

  exec Hyprland
}


alias nduf = /home/pe/development/disk-size/nduf
