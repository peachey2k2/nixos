rec {
  description = "six seven";

  # TODO: move these to somewhere else (idk rn since config.nix already exists)
  nixConfig = {
    experimental-features = [
      "flakes"         # duh
      "nix-command"    # duh
      "pipe-operators" # Gives access to <| and |>, Prior works like $ in Haskell, latter is the same as in Elixir.
      "cgroups"
    ];

    extra-substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://cache.iog.io"
      "https://cuda-maintainers.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://install.determinate.systems"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPiCe+467rJVel7/TrsBQQQTfvs5cBUOQ="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nqlt0="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    ];

    accept-flake-config      = true;
    builders-use-substitutes = true;
    flake-registry           = "";
    http-connections         = 50;
    max-substitution-jobs    = 32;
    lazy-trees               = true; # determinate
    show-trace               = true;
    trusted-users            = [ "root" "@build" "@wheel" "@admin" ];
    use-cgroups              = true;
    warn-dirty               = false;
  };

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs-unstable.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

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

  outputs = inputs @ {
    self,
    determinate,
    nixpkgs,
    nixpkgs-unstable,
    # nixpkgs-master,
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
          determinate.nixosModules.default
          
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
        ];
      };

      packages.${system} = {
        generated-configs = (import ./config.nix {inherit pkgs;}).run {};
      };

      apps.${system} = {
        generate-configs = {
          type = "app";
          program = 
            let
              configs = self.packages.${system}.generated-configs;
              script = pkgs.writeShellScriptBin "install-configs" ''
                # sneaky gc root
                mkdir -p "$HOME/.local/state"
                "${pkgs.nix}/bin/nix-store" \
                  --add-root "$HOME/.local/state/latest-configs" \
                  --realise "${configs}"

                echo "Installing config files to ~/.config"
                mkdir -p "$HOME/.config"

                cp -r --no-preserve=mode "${configs}/config/"* "$HOME/.config/"
                echo "Done!"
              '';
            in
              "${script}/bin/install-configs"; 
        };
      };
    };
}
