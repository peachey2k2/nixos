export def cheatsheet [] {
  {
    command: "systemd-timers"
    aliases: ["systemd-timers", "systemd", "timers", "timer"]
    title: "systemd Timers"
    description: "Create, enable, inspect, and debug timer-based jobs"
    rows: [
      {task: "List all timers", command: "systemctl list-timers --all", note: "Add --user for user timers"}
      {task: "Show timer unit details", command: "systemctl status <name>.timer", note: "Last/next run and activation state"}
      {task: "Show linked service unit", command: "systemctl status <name>.service", note: "Useful when timer triggers but work fails"}
      {task: "Enable + start timer now", command: "sudo systemctl enable --now <name>.timer", note: "Creates boot-time activation symlink"}
      {task: "Disable + stop timer", command: "sudo systemctl disable --now <name>.timer", note: "Leaves unit files in place"}
      {task: "Run job immediately", command: "sudo systemctl start <name>.service", note: "Manual one-shot run for testing"}
      {task: "Reload changed unit files", command: "sudo systemctl daemon-reload", note: "Run after editing .timer/.service files"}
      {task: "Journal logs for timer/service", command: "journalctl -u <name>.timer -u <name>.service -f", note: "Follow live execution output"}
      {task: "Validate calendar expression", command: "systemd-analyze calendar \"Mon..Fri 09:00\"", note: "Shows normalized schedule + next elapse"}
      {task: "Create user timer file path", command: "~/.config/systemd/user/<name>.timer", note: "Pair with matching <name>.service"}
      {task: "Create system timer file path", command: "/etc/systemd/system/<name>.timer", note: "System-wide service account or root"}
      {task: "Catch up after downtime", command: "Persistent=true", note: "Add in [Timer] to run missed events"}
      {task: "NixOS: every 15 minutes", command: "systemd.timers.\"cache-prune\" = { wantedBy = [\"timers.target\"]; timerConfig = { OnCalendar = \"*:0/15\"; Unit = \"cache-prune.service\"; Persistent = true; }; };", note: "Add matching systemd.services.\"cache-prune\""}
      {task: "NixOS: boot + every hour", command: "systemd.timers.\"sync-job\".timerConfig = { OnBootSec = \"5m\"; OnUnitActiveSec = \"1h\"; Unit = \"sync-job.service\"; };", note: "Useful for recurring sync jobs"}
      {task: "NixOS: daily with jitter", command: "systemd.timers.\"db-backup\".timerConfig = { OnCalendar = \"03:00\"; RandomizedDelaySec = \"30m\"; Persistent = true; Unit = \"db-backup.service\"; };", note: "Avoids thundering herd across hosts"}
      {task: "NixOS: oneshot service pair", command: "systemd.services.\"db-backup\" = { script = ''/run/current-system/sw/bin/pg_dump ...''; serviceConfig = { Type = \"oneshot\"; User = \"postgres\"; }; };", note: "Timer triggers this service unit"}
    ]
  }
}
