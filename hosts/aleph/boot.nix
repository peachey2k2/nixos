{ config, pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };

      timeout = 1;
      efi.canTouchEfiVariables = true;
    };

    kernelPackages = pkgs.linuxPackages_zen;

    kernelModules = [
      "v4l2loopback"
      "lenovo-legion-module"
      "usbmon"
    ];

    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback
      lenovo-legion-module
    ];

    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
      options legion_laptop force=1
    '';

    supportedFilesystems = [ "ntfs" ];
  };
}
