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

    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    # nixpkgs-master,
    home-manager,
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
                unstable = nixpkgs-unstable.legacyPackages.${prev.system};
                # master = nixpkgs-master.legacyPackages.${prev.system};
                zen-browser = inputs.zen-browser.packages."${system}".default;
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
