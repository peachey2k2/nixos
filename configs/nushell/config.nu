use std/clip

source nushell.nu
source cmds.nu

use lib/todo.nu *
use lib/cheatsheets/mod.nu *

if not ("DISPLAY" in $env) and (tty) == "/dev/tty1" {
  try {
    nvidia-smi --query-gpu=name --format=csv,noheader o+e> /dev/null
    $env.NVIDIA_GPU_ENABLED = "1"
  } catch {}

  exec start-hyprland
}

if not ((tty) =~ "/dev/tty") and "IS_NUSHELL_INITIALIZED" in $env == false {
  $env.IS_NUSHELL_INITIALIZED = true;
  source opener.nu
}
