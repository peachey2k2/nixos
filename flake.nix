rec {
  description = "My NixOS Configuration";

  # TODO: move these to somewhere else (idk rn since config.nix already exists)
  nixConfig = {
    experimental-features = [
      "flakes"         # duh
      "nix-command"    # duh
      "pipe-operators" # Gives access to <| and |>, Prior works like $ in Haskell, latter is the same as in Elixir.
    ];

    extra-substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://cache.iog.io"
      "https://cuda-maintainers.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPiCe+467rJVel7/TrsBQQQTfvs5cBUOQ="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nqlt0="
    ];

    max-substitution-jobs = 32;
    http-connections = 50;
  };

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
    caelestia-shell.inputs.quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell?rev=1ddb355121484bcac70f49edd4bd006b1d3a753e";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    caelestia-cli.url = "github:caelestia-dots/cli";
    caelestia-cli.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    # nixpkgs-master,
    home-manager,
    nur,
    ...
  }:
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
              inherit nixConfig;
            }
          )

          {
            nixpkgs.config = {
              allowUnfree = true;
              allowBroken = true;

              packageOverrides = with pkgs; {
                svlangserver = callPackage ./packages/svlangserver/default.nix {};
                marked = callPackage ./packages/marked/default.nix {};
              };
            };

            nixpkgs.overlays = [
              nur.overlays.default
              (final: prev: {
                unstable = nixpkgs-unstable.legacyPackages.${system};
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
