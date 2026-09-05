{ ... }:

{
  systemd.settings.Manager.DefaultTimeoutStopSec = "4s";

  # PID 1 -> user@.service: how long before SIGKILLing the user manager
  systemd.services."user@".serviceConfig.TimeoutStopSec = "4s";

  # libvirtd has its own timeout; override it
  systemd.services.libvirtd.serviceConfig.TimeoutStopSec = "4s";

  # user manager -> user services: how long before SIGKILL
  systemd.user.settings.Manager.DefaultTimeoutStopSec = "4s";
}
