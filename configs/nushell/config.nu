use std/clip

source nushell.nu
source cmds.nu

use lib/todo.nu *

if "IS_SHELL_INITIALIZED" in $env == false {
  $env.IS_SHELL_INITIALIZED = true;
  source opener.nu
}

if not ("DISPLAY" in $env) and (tty) == "/dev/tty1" {
  try {
    nvidia-smi --query-gpu=name --format=csv,noheader o+e> /dev/null
    $env.NVIDIA_GPU_ENABLED = "1"
  } catch {}

  exec Hyprland
}

