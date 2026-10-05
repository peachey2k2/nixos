{
  aleph = {
    system = "x86_64-linux";
    enableOverlays = true;
    nixpkgsConfig.allowUnfree = true;
    # radicle-node 1.10.3 flagged insecure upstream (unencrypted P2P traffic).
    nixpkgsConfig.permittedInsecurePackages = [ "radicle-node-1.10.3" ];
    modules = [ ./aleph ];
  };

  dalet = {
    system = "x86_64-linux";
    nixpkgsConfig.allowUnfree = true;
    modules = [ ./dalet ];
  };
}
