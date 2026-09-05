{ pkgs, ... }:

{
  services = {
    # CUPS printing service and driverless network printer discovery.
    printing = {
      enable = true;
      drivers = with pkgs; [
        cups-filters
        cups-browsed
        gutenprint
        hplip
        brlaser
        epson-escpr
        epson-escpr2
      ];
    };

    # mDNS / DNS-SD discovery for AirPrint and IPP Everywhere printers.
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # Auto-discover supported USB printers as local IPP devices.
    ipp-usb.enable = true;
  };

  environment.systemPackages = with pkgs; [
    system-config-printer
  ];
}
