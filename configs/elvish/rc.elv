use re

if (and (==s $E:DISPLAY "") (==s (tty) "/dev/tty1")) {
  exec Hyprland
}

fn git-prompt {
  var name add rem = '' '' ''
  try {
    set name = ' '(basename (git symbolic-ref --short HEAD 2> /dev/null))
    var diff = (git diff --shortstat)
    set add = ' +'(re:find '\b(\d+) insertions\(\+\)' $diff)[groups][1][text]
    set rem = ' -'(re:find '\b(\d+) deletions\(\-\)' $diff)[groups][1][text]
  } catch { }
  put $name$add$rem
}

set edit:prompt = {
  var cwd = (tilde-abbr $pwd)
  var git = (git-prompt)
  if (!=s $E:DISPLAY "") {    
    styled " "$cwd '#ffffff' 'bg-#1f6fdf'
    if (!=s $git "") {
      styled ' ' '#1f6fdf' 'bg-#af8f1f'
      styled $git '#ffffff' 'bg-#af8f1f'
      styled " " '#af8f1f'
    } else {
      styled " " '#1f6fdf'
    }
  } else {
    put " "$cwd" "$git"> "
  }
}

set edit:rprompt = (constantly ^
)

var lastcmd = ''

set edit:after-readline = [{ |line|
  set lastcmd = $line
}]

# https://elv.sh/ref/edit.html#$edit:after-command
set edit:after-command = [{ |m|
  if (and (!=s $lastcmd "clear") (!=s $lastcmd "")) {
    echo ''
  }
}]

fn last-exception {
  show $edit:exceptions[-1]
}


fn ls {|@a| e:ls --color $@a }

use ./zoxide
fn cd {|@a| zoxide:__zoxide_z $@a}

fn nix-shell {|@a| cached-nix-shell $@a}

fn %clear-backups {|@a| ~/nixos/scripts/clear-backups.sh $@a}
fn %config-reload {|@a| ~/nixos/scripts/config-reload.sh}
fn %edit {|@a| hx ~/nixos/flake.nix -w ~/nixos}
fn %list-packages {|@a| nix-store -q --requisites /run/current-system/sw | fzf}
fn %logs {|@a| tail ~/nixos/log.txt}
fn %rebuild {|@a| ~/nixos/scripts/rebuild.sh}

var fzf = ''
fn fz {|@a|
  set fzf = (fzf --walker=dir,file,hidden)
  echo $fzf
}

# Enable the universal command completer if available.
# See https://github.com/rsteube/carapace-bin
if (has-external carapace) {
  eval (carapace _carapace | slurp)
}

