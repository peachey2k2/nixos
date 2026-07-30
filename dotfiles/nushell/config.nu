use std/clip

source nushell.nu
source cmds.nu
source keybinds.nu

source-env (if ("/etc/secrets.nu" | path exists) { "/etc/secrets.nu" } else { null })


if not ("DISPLAY" in $env) and (tty) == "/dev/tty1" {
  try {
    nvidia-smi --query-gpu=name --format=csv,noheader o+e> /dev/null
    $env.NVIDIA_GPU_ENABLED = "1"
  } catch {}

  # niri gets stuck in a loop calling itself unless we do this to
  # lock it out of reloading the nushell config
  exec niri-session -l
}

if "TMUX" in $env {
  $env.TERM_PROGRAM = "beer"
} else if ($env.TERM? | default "") == "beer" {
  let socket = $"beer-((tty) | path basename)"
  exec tmux -L $socket new-session -A -s main
}

if (not (((tty) =~ "/dev/tty") or "IS_NUSHELL_INITIALIZED" in $env)) {
  $env.IS_NUSHELL_INITIALIZED = true;
  source opener.nu
}

