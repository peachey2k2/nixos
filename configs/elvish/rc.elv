use re

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

var last-cmd = ''
set edit:after-readline = [{ |line|
  set last-cmd = $line
}]

set edit:prompt = {
  var cwd = (prompt-cwd)
  var git = (prompt-git)
  if (and (!=s $last-cmd "clear") (!=s $last-cmd "")) {
    put "\n"
  }
  if (!=s $E:DISPLAY '') {    
    if (!=s $git '') {
      styled ' '$git '#ffffff' 'bg-#af8f1f'
      styled '' '#af8f1f' 'bg-#1f6fdf'
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

fn last-exception {
  show $edit:exceptions[-1]
}

fn ls {|@a| e:ls --color $@a }

use ./zoxide
fn cd {|@a| zoxide:__zoxide_z $@a}

fn %clear-backups {|@a| ~/nixos/scripts/clear-backups.sh $@a}
fn %config-reload {|@a| ~/nixos/scripts/config-reload.sh}
fn %edit {|@a| hx ~/nixos/flake.nix -w ~/nixos}
fn %list-packages {|@a| nix-store -q --requisites /run/current-system/sw | fzf}
fn %logs {|@a| tail ~/nixos/log.txt}
fn %rebuild {|@a| ~/nixos/scripts/rebuild.sh}

var fzf = ''
fn fz {|@a|
  set fzf = (fzf --walker=dir,file,hidden $@a)
  echo $fzf
}

# Enable the universal command completer if available.
# See https://github.com/rsteube/carapace-bin
if (has-external carapace) {
  eval (carapace _carapace | slurp)
}

