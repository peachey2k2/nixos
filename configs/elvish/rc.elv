use re

fn env-or-def {|envvar def|
  if (!=s $envvar '') { put $envvar } else { put $def }
}

var shell-depth = (env-or-def $E:NIX_SHELL_DEPTH 0)

if (and (==s $E:DISPLAY "") (==s (tty) "/dev/tty1")) {
  exec Hyprland
}

fn prompt-git {
  var name add rem = '' '' ''
  try {
    set name = ' '(basename (git symbolic-ref --short HEAD 2> /dev/null))
    var diff = (git diff --shortstat)
    set add = ' +'(re:find '\b(\d+) insertions\(\+\)' $diff)[groups][1][text]
    set rem = ' -'(re:find '\b(\d+) deletions\(\-\)' $diff)[groups][1][text]
  } catch { }
  put $name$add$rem
}

fn prompt-cwd {
  var cwd = (tilde-abbr $pwd)
  put (or (re:find '[^/]*/[^/]*$' $cwd)[text] $cwd)
}

var last-cmd = 'NONE££'
set edit:after-readline = [{ |line|
  set last-cmd = $line
}]

set edit:prompt = {
  var cwd = (prompt-cwd)
  var git = (prompt-git)
  if (and (!=s $last-cmd "clear") (!=s $last-cmd "NONE££")) {
    put "\n"
  }
  if (!=s $E:DISPLAY '') {
    styled ' '$shell-depth '#ffffff' 'bg-#df3f1f'
    if (!=s $git '') {
      styled '' '#df3f1f' 'bg-#af8f1f'
      styled ' '$git '#ffffff' 'bg-#af8f1f'
      styled '' '#af8f1f' 'bg-#1f6fdf'
    } else {
      styled '' '#df3f1f' 'bg-#1f6fdf'
    }
    styled ' '$cwd '#ffffff' 'bg-#1f6fdf'
    styled ' ' '#1f6fdf'
  } else {
    put $cwd" >> "
  }
}

var last-duration

set edit:rprompt = {
  var a = (if (>= $last-duration '99.99') { put '>99.99' } else { put (printf '%.2f' $last-duration) })
  if (!=s $E:DISPLAY '') {    
    styled '' '#1f6fdf'
    styled $a's ' '#ffffff' 'bg-#1f6fdf' 
  } else {
    put $a's'
  }
}

# https://elv.sh/ref/edit.html#$edit:after-command
set edit:after-command = [{ |m|
  set last-duration = $m[duration]
}]

fn file-exists {|file|
  try { if (stat $file 2> /dev/null) { put $true } } catch { put $false }
}

# zoxide
use ./zoxide
# fn cd {|@a| zoxide:__zoxide_z $@a}

# Enable the universal command completer if available.
# See https://github.com/rsteube/carapace-bin
if (has-external carapace) {
  eval (carapace _carapace | slurp)
}


##### helpers #####
fn %clear-backups {|@a| ~/nixos/scripts/clear-backups.sh $@a}
fn %config-reload {|@a| ~/nixos/scripts/config-reload.sh}
fn %edit {|@a| hx ~/nixos/flake.nix -w ~/nixos}
fn %list-packages {|@a| nix-store -q --requisites /run/current-system/sw | fzf}
fn %logs {|@a| tail ~/nixos/log.txt}
fn %rebuild {|@a| ~/nixos/scripts/rebuild.sh}

fn %devel {|@a|
  var proj = (
    try {
      put ~"/development/"(ls -1 ~/development | fzf)
    } catch { return }
  )
  put $proj
  if (file-exists $proj"/flake.nix") {
    nix develop $proj --command sh -c "cd "$proj" && NIX_SHELL_DEPTH="(+ $shell-depth 1)" elvish"
  } else {
    cd $proj
  }
}

var fzf = ''
# calls `fzf` and puts the result into `$fzf`
fn fz {|@a|
  try {
    set fzf = (fzf --walker=dir,file,hidden $@a)
    echo $fzf
  } catch { }
}

# gets the last rc exception
fn last-exception {
  if (== (count $edit:exceptions) 0) {
    echo "no exceptions found"
  } else {
    show $edit:exceptions[-1]
  }
}

##### overrides #####

fn ls {|@a| e:ls --color $@a }

fn nix {|subcmd @rest|
  if (==s $subcmd "develop") {
    e:nix develop --command sh -c "NIX_SHELL_DEPTH="(+ $shell-depth 1)" elvish" $@rest
  } else {
    e:nix $subcmd $@rest
  }
}

fn duf {|@rest|
  e:duf --only-mp /,/boot $@rest
}
