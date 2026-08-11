
alias "cal" = cal --week-start "mo"

def --wrapped "pi" [...args] {
  let pi_dir = ($env.HOME | path join ".config" "pi")
  with-env {
    PI_NERD_FONTS: "1",
    PI_OFFLINE: "1",
    PI_CODING_AGENT_DIR: $pi_dir,
    PI_EXTENSION_CONFIG_DIR: $pi_dir
  } { ^pi ...$args }
}

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

def nix-dir [] {
  $env.NIX_DIR
}

def nix-log [tag: string, message: string] {
  let log_file = ((nix-dir) | path join log.txt)
  mkdir ($log_file | path dirname)
  $"(date now | format date '%d-%m-%Y %H:%M') [($tag)] ($message)(char newline)" | save --append $log_file
}

def "sort-packages" [] {
}

# clear all .backup files to prevent conflicts on config replaces
def "!clear-backups" [backup_dir?: path] {
  let dir = ($backup_dir | default ~/.config | path expand)
  let backups = (glob --no-dir --depth 20 ($dir | path join "**" "*.backup"))

  if ($backups | is-empty) {
    print "no backup files to remove."
    return
  }

  print $"--- (($backups | length)) file(s) found ---"
  $backups | each { print }
  print ""

  let answer = (input "are you sure to delete them all? (y/n) ")
  if $answer == "y" {
    $backups | each {|backup| rm $backup }
    print "removed all."
  } else {
    print "cancelled."
  }
}

# rebuild all config files from dotfiles/config generator
def --wrapped "!config-reload" [...args] {
  let dir = (nix-dir)
  git -C $dir add .
  nix run $"($dir)#generate-configs" ...$args
}

# edit the system flake
alias "!edit" = hx /home/me/nixos/flake.nix -w /home/me/nixos

# list all store paths for the current system derivation
alias "!list" = nix-store -q --requisites /run/current-system/sw

# calls `tail` on script logs
alias "!logs" = tail /home/me/nixos/log.txt

# rebuild the system derivation
def --wrapped "!rebuild" [
  --no-push
  --no-update
  ...args
] {
  let dir = (nix-dir)
  let host = (hostname)

  git -C $dir add .

  let updated_today = (
    try {
      open ($dir | path join log.txt)
      | lines
      | reverse
      | any {|line| $line =~ $"^(date now | format date '%d-%m-%Y') ..:.. \\[REBUILD\\] recreated flake\\.lock" }
    } catch { false }
  )

  if $updated_today or $no_update {
    nh os switch $dir -H $host --accept-flake-config ...$args
  } else {
    sh -c "cd $NIX_DIR && tack update"
    nh os switch $dir -H $host --update --accept-flake-config --impure ...$args
  }

  let result = $env.LAST_EXIT_CODE
  sort-packages

  if $result == 0 {
    if not ($updated_today or $no_update) {
      nix-log REBUILD "recreated flake.lock"
    }
    nix-log REBUILD "rebuild successful"
    if not $no_push {
      nix-autopush-hook
    }
  } else {
    nix-log REBUILD "failed to rebuild"
  }
}

# commit/push once per day if there are changes
def "nix-autopush-hook" [] {
  let dir = (nix-dir)
  cd $dir
  git add .

  let today = (date now | format date "%d-%m-%Y %H:%M")
  let last_message = (try { git log --max-count 1 --pretty=%B | lines | last | str trim } catch { "" })

  if $last_message != $today {
    if not ((git status --porcelain | str trim) | is-empty) {
      git commit -m $today
      git push origin master

      if $env.LAST_EXIT_CODE == 0 {
        nix-log AUTOPUSH "Push successful."
      } else {
        nix-log AUTOPUSH "Push failed."
      }
    } else {
      nix-log AUTOPUSH "No changes to commit."
    }
  } else {
    nix-log AUTOPUSH "Already commited a change today."
  }
}

# its the fortify warning bullshit on -o0
# ~@amaanq
$env.NIX_HARDENING_ENABLE = ($env.NIX_HARDENING_ENABLE? | default '' | split row ' ' | where { $in !~ 'fortify' } | str join ' ')

def --wrapped sudo [...rest] {
  sudo --run0-extra-arg --background= ...$rest
}

def --wrapped run0 [...rest] {
  let pass_env = ('--env' in $rest)
  let rest = ($rest | where { $in != '--env' })
  let env_args = if $pass_env {
    ^env -0
    | split row (char nul)
    | where { not ($in | is-empty) }
    | each { |x| $"--setenv=($x)" }
  } else {
    []
  }

  (^run0
    --background=
    ...$env_args
    --setenv=TERMINFO=($env.TERMINFO?)
    --setenv=STARSHIP_CONFIG=($env.HOME)/.config/starship.toml
    --setenv=SHELL_DEPTH=(($env.SHELL_DEPTH | into int) + 1)
    --setenv=NIX_SHELL_DEPTH=($env.NIX_SHELL_DEPTH | into int)
    --setenv=IS_NUSHELL_INITIALIZED=1
    ...$rest)
}

def --wrapped "!env" [...rest] {
  NIXPKGS_ALLOW_UNFREE=1 NIXPKGS_ALLOW_INSECURE=1 nix shell --impure ...(
    $rest | each {|x|
      let x = $x | into string;

      if not (
        ($x | str contains "#") or
        ($x | str contains ":") or
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

def --wrapped "!run" [...rest] {
  let separator = ($rest | enumerate | where item == "--" | get index | first | default null)
  let nix_args = if $separator == null { $rest } else { $rest | take $separator }
  let program_args = if $separator == null { [] } else { $rest | skip ($separator + 1) }
  let normalized_nix_args = (
    $nix_args | each {|x|
      let x = $x | into string;

      if not (
        ($x | str contains "#") or
        ($x | str contains ":") or
        ($x | str starts-with "-") or
        ($x | str starts-with ".") or
        ($x | str starts-with "/")
      ) {
        "nixpkgs#" ++ $x
      } else {
        $x
      }
    }
  )
  let args = if $separator == null { $normalized_nix_args } else { $normalized_nix_args | append "--" | append $program_args }

  NIXPKGS_ALLOW_UNFREE=1 NIXPKGS_ALLOW_INSECURE=1 nix run --impure ...$args
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

$env.RUST_BACKTRACE = 1


alias nduf = /home/me/Projects/disk-size/nduf
