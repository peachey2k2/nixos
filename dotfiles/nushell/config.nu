use std/clip

source nushell.nu
source cmds.nu

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
  SHELL=sh sh -c "niri-session"
}

if not ((tty) =~ "/dev/tty") and "IS_NUSHELL_INITIALIZED" in $env == false {
  $env.IS_NUSHELL_INITIALIZED = true;
  source opener.nu
}
