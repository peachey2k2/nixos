use re


fn git-branch {
  var name add rem = '' '' ''
  try {
    set name = ' '(basename (git symbolic-ref --short HEAD 2> /dev/null))
    set add = ' +'(re:find '\b(\d+) insertions\(\+\)' (git diff --shortstat))[groups][1][text]
    set rem = ' -'(re:find '\b(\d+) deletions\(\-\)' (git diff --shortstat))[groups][1][text]
  } catch { }
  put $name$add$rem
}

set edit:prompt = {
  var git = (git-branch)
  var branch = (if (!=s $git "") { put $git } else { put '' })

  styled " "(tilde-abbr $pwd)" " '#000000' 'bg-#1f6fdf'
  styled $branch '#000000' 'bg-#1f6fdf'
  styled " " '#1f6fdf'
}

set edit:rprompt = (constantly ^
)

var lastcmd = ''

set edit:after-readline = [{ |line|
  set lastcmd = $line
}]

# https://elv.sh/ref/edit.html#$edit:after-command
set edit:after-command = [{ |m|
  if (!=s $lastcmd "clear") {
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


