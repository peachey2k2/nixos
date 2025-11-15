{
  description = "My NixOS Configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/25.05";

    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    # nixpkgs-unstable.inputs.nixpkgs.follows = "nixpkgs";

    # nixpkgs-master.url = "nixpkgs/master";
    # nixpkgs-master.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    zen-browser.url = "github:crashim03/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    fenix.url = "github:nix-community/fenix/monthly";
    fenix.inputs.nixpkgs.follows = "nixpkgs";

    caelestia-shell.url = "github:caelestia-dots/shell";
    caelestia-shell.inputs.nixpkgs.follows = "nixpkgs-unstable";

    caelestia-cli.url = "github:caelestia-dots/cli";
    caelestia-cli.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    # nixpkgs-master,
    home-manager,
    nur,
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
          (
            import ./system.nix {
              user = username;
            }
          )

          {
            nixpkgs.overlays = [
              (final: prev: {
                unstable = nixpkgs-unstable.legacyPackages.${system};
                nur = nur.legacyPackages.${system};
                # master = nixpkgs-master.legacyPackages.${system};
                zen-browser = inputs.zen-browser.packages.${system}.default;
                fenix = inputs.fenix.packages.${system}.default;
                caelestia-shell = inputs.caelestia-shell.packages.${system}.with-cli;
                caelestia-cli = inputs.caelestia-cli.packages.${system}.with-shell;
              })
            ];
          }

          home-manager.nixosModules.home-manager {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true;
              backupFileExtension = "backup";
              users.${username} = import ./home.nix;
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
