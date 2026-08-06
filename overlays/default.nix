{
  inputs,
  system,
  nixpkgsConfig,
}:

[
  inputs.nur.overlays.default
  inputs.fenix.overlays.default
  inputs.run0-sudo-shim.overlays.default

  (final: prev: {
    svlangserver = final.callPackage ../packages/svlangserver { };
    marked = final.callPackage ../packages/marked { };
    zynk-cli = final.callPackage ../packages/zynk-cli { };
    zcode = final.callPackage ../packages/zcode { };
    jai = final.callPackage ../packages/jai { };
    jails = final.callPackage ../packages/jails { };
    nethack = final.callPackage ../packages/nethack { };
    # nerdfonts-custom = final.callPackage ../packages/nerdfonts-custom { };

    freeoffice = prev.freeoffice.override {
      officeVersion = {
        edition = "2024";
        version = "1234";
        hash = "sha256-q5QUevkSxdh622ZMhwbO44HLJowpg0vwv9de7hdOUQQ=";
      };
    };

    zen-browser = inputs.zen-browser.packages.${system}.default;
    _0fetch = inputs._0fetch.packages.${system}.default;
    pi = final.callPackage ../packages/pi-alternate {
      src = inputs.pi-alternate;
    };
    comfyui = inputs.comfyui.packages.${system}.cuda;
    nilshell = inputs.nilshell.packages.${system}.default;
    # beer = inputs.beer.packages.${system}.default.overrideAttrs (old: {
    #   patches = (old.patches or [ ]) ++ [
    #     ../patches/beer-shift-tab.patch
    #   ];
    # });

    # Nixpkgs builds Steelix's newer queries against Helix's older grammar lock.
    # Keep the Steel-enabled binary, but use Helix's internally consistent runtime.
    steelix = final.symlinkJoin {
      name = "steelix-fixed-runtime";
      paths = [ prev.steelix ];
      nativeBuildInputs = [ final.makeWrapper ];
      postBuild = ''
        rm $out/bin/hx
        makeWrapper $out/bin/.hx-wrapped $out/bin/hx \
          --set HELIX_RUNTIME "${prev.helix.runtime}"
      '';
    };
  })
]
