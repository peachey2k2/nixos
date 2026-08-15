{
  outputs =
    { self, ... }@args:
    let
      # We use tack to manage the input pins.
      # https://github.com/manic-systems/tack
      inputs = (import ./.tack) {
        overrides = args.tackOverrides or { };
      };

      nixConfig = import ./nix-config.nix;

      nixpkgsConfig = {
        allowUnfree = true;
      };

      hosts = import ./hosts;

      flakePartsInputs = args // inputs;

      overlaysFor = system:
        import ./overlays {
          inherit inputs system nixpkgsConfig;
        };

      mkHost = hostname: host:
        let
          system = host.system;
          username = "me";
          homeDirectory = "/home/${username}";
          modules = host.modules;
        in
        inputs.nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit
              inputs
              system
              username
              hostname
              homeDirectory
              nixConfig
              nixpkgsConfig
              ;
          };

          modules = [
            {
              nixpkgs.config = nixpkgsConfig;
              nixpkgs.overlays = overlaysFor system;
            }
            ./modules/system
          ]
          ++ modules;
        };
    in
    inputs.flake-parts.lib.mkFlake { inputs = flakePartsInputs; } {
      systems = [ "x86_64-linux" ];

      perSystem =
        { system, ... }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            config = nixpkgsConfig;
            overlays = overlaysFor system;
          };

          generatedConfigs = (import ./config-generator.nix { inherit pkgs; }).run { };

          installConfigs = pkgs.writeShellApplication {
            name = "generate-configs";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.nix
            ];
            text = ''
              mkdir -p "$HOME/.local/state"
              nix-store \
                --add-root "$HOME/.local/state/latest-configs" \
                --realise "${generatedConfigs}"

              echo "Installing config files to ~/.config"
              mkdir -p "$HOME/.config"
              cp -r --no-preserve=mode "${generatedConfigs}/config/"* "$HOME/.config/"
              echo "Done!"
            '';
          };
        in
        {
          formatter = pkgs.nixfmt-rfc-style;

          packages = {
            generated-configs = generatedConfigs;
            generate-configs = installConfigs;
          };

          apps = {
            generate-configs = {
              type = "app";
              program = "${installConfigs}/bin/generate-configs";
            };
          };
        };

      flake = {
        nixosConfigurations = builtins.mapAttrs mkHost hosts;
      };
    };
}
