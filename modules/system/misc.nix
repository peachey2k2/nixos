{ ... }:

{
  systemd.settings.Manager.DefaultTimeoutStopSec = "4s";

  # PID 1 -> user@.service: how long before SIGKILLing the user manager
  systemd.services."user@".serviceConfig.TimeoutStopSec = "4s";

  # libvirtd has its own timeout; override it
  systemd.services.libvirtd.serviceConfig.TimeoutStopSec = "4s";

  # user manager -> user services: how long before SIGKILL
  systemd.user.settings.Manager.DefaultTimeoutStopSec = "4s";

  services.udev.extraRules = ''
    # AULA F75 / BY Tech keyboard userspace control access.
    # Wired USB: 258a:010c
    # 2.4G dongle: 3554:fa09
    SUBSYSTEM=="usb", ATTRS{idVendor}=="258a", ATTRS{idProduct}=="010c", MODE="0666", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="258a", ATTRS{idProduct}=="010c", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="fa09", MODE="0666", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="fa09", MODE="0666", TAG+="uaccess"
  '';
}
