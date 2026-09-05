{
  aleph = {
    system = "x86_64-linux";
    enableOverlays = true;
    nixpkgsConfig.allowUnfree = true;
    modules = [ ./aleph ];
  };

  dalet = {
    system = "x86_64-linux";
    modules = [ ./dalet ];
  };
}
