{
  config,
  lib,
  pkgs,
  inputs,
  system,
  nixpkgsConfig,
  ...
}:

let
  # Mesa 26.2.0 hangs the Alder Lake i915 OpenGL context. Keep the graphics
  # driver set on the last known-good nixpkgs revision until upstream #16066
  # is fixed: https://gitlab.freedesktop.org/mesa/mesa/-/work_items/16066
  mesaPkgs = import inputs.mesa {
    inherit system;
    config = nixpkgsConfig;
  };
in
{
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    package = mesaPkgs.mesa;
    package32 = mesaPkgs.pkgsi686Linux.mesa;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
    # of just the bare essentials.
    powerManagement.enable = true;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = true;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at: 
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    #
    # NOTE: rtx5060 (or any blackwell gpu) is apparently not supported by the closed
    # source kernel module so yeah
    open = true;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    branch = "bleeding_edge";

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      # Make sure to use the correct Bus ID values for your system!
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}
