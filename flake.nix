{
  description = "My NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    # determinate,
    ...
  }@inputs:
    let
      username = "pe";
      homeDir = "/home/" + username;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      nixosConfigurations.chey = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./system.nix

          {
            nixpkgs.overlays = [
              (final: prev: {
                unstable = nixpkgs-unstable.legacyPackages.${prev.system};
              })
            ];
          }

          # determinate.nixosModules.default

          home-manager.nixosModules.home-manager {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true;
              backupFileExtension = "backup";
              users.pe = import ./home.nix;
            };
          }
        ];
      };
      packages.${system} = {
        generated-configs = (import ./config.nix {inherit pkgs;}).standaloneConfig {};
      };

      apps.${system} = {
        generate-configs = {
          type = "app";
          program = 
            let
              configs = self.packages.${system}.generated-configs;
              script = pkgs.writeShellScriptBin "install-configs" ''
                echo "Installing config files to ~/.config"
                mkdir -p $HOME/.config
                cp -r --no-preserve=mode ${configs}/config/* $HOME/.config/
                echo "Done!"
              '';
            in
              "${script}/bin/install-configs"; 
        };
      };
    };
}
