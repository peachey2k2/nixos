use std/clip

source nushell.nu
source cmds.nu
source keybinds.nu

source-env (if ("/etc/secrets.nu" | path exists) { "/etc/secrets.nu" } else { null })


use lib/todo.nu *
use lib/cheatsheets/mod.nu *

if not ("DISPLAY" in $env) and (tty) == "/dev/tty1" {
  try {
    nvidia-smi --query-gpu=name --format=csv,noheader o+e> /dev/null
    $env.NVIDIA_GPU_ENABLED = "1"
  } catch {}

  # niri gets stuck in a loop calling itself unless we do this to
  # lock it out of reloading the nushell config
  exec niri-session -l
}

if not ((tty) =~ "/dev/tty") and "IS_NUSHELL_INITIALIZED" in $env == false {
  $env.IS_NUSHELL_INITIALIZED = true;
  source opener.nu
}

# Beer has no native tabs, so use tmux windows as its tab bar. The TERM check
# keeps other terminals unchanged and prevents nesting inside tmux panes.
if ($env.TERM? | default "") == "beer" and ($env.TMUX? | default "") == "" {
  exec tmux new-session -A -s main
}
