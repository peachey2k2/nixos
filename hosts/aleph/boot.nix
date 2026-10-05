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
      # rtw89_8852be hangs after a while under PCIe ASPM / PS mode:
      # "read rf busy swsi" + "timed out to flush queues". Disable both.
      options rtw89_pci disable_aspm_l1=Y disable_aspm_l1ss=Y
      options rtw89_core disable_ps_mode=Y
    '';

    supportedFilesystems = [ "ntfs" ];
  };
}
