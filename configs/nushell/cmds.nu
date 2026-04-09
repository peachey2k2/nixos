
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

# clear all .backup files to prevent conflicts on config replaces
alias "%clear-backups" = /home/pe/nixos/scripts/clear-backups.sh          

# rebuild all config files in nixos/configs
alias "%config-reload" = /home/pe/nixos/scripts/config-reload.sh          

# edit the system flake
alias "%edit"          = hx /home/pe/nixos/flake.nix -w /home/pe/nixos    

# list all store paths for the current system derivation
alias "%list"          = nix-store -q --requisites /run/current-system/sw 

# calls `tail` on script logs
alias "%logs"          = tail /home/pe/nixos/log.txt                      

# rebuild the system derivation
alias "%rebuild"       = /home/pe/nixos/scripts/rebuild.sh                

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
  print "use run0 instead!!!! initiating 5 sec wait of shame"
  sleep 5sec
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


alias nduf = /home/pe/development/disk-size/nduf

