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
    # Autolith 0.39.1 requires SBCL 2.6.6; keep its runtime and Lisp
    # package set aligned until upstream supports the newer nixpkgs SBCL.
    autolith =
      let
        pkgs = final // {
          sbcl = final.sbcl_2_6_6;
          sbclPackages = final.sbcl_2_6_6.pkgs;
        };
      in
      import "${inputs.autolith}/nix/package.nix" {
        inherit pkgs;
        src = inputs.autolith;
      };
    tack = inputs.tack.packages.${system}.default;
    reborder = inputs.reborder.packages.${system}.default;
    blank = inputs.blank.packages.${system}.default;
    jai = final.callPackage ../packages/jai { };
    jails = final.callPackage ../packages/jails { };
    nethack = final.callPackage ../packages/nethack { };
    freeoffice = prev.freeoffice.override {
      officeVersion = {
        edition = "2024";
        version = "1234";
        hash = "sha256-q5QUevkSxdh622ZMhwbO44HLJowpg0vwv9de7hdOUQQ=";
      };
    };

    # Temporarily disabled: the upstream tokscale test suites are broken.
    tokscale = prev.tokscale.overrideAttrs (_: {
      doCheck = false;
      doInstallCheck = false;
    });

    zen-browser = inputs.zen-browser.packages.${system}.default;
    _0fetch = inputs._0fetch.packages.${system}.default;
    pi = inputs.llm-agents.packages.${system}.pi;
    chatgpt = inputs.llm-agents.packages.${system}.chatgpt;
    comfyui = inputs.comfyui.packages.${system}.cuda;
    nilshell = inputs.nilshell.packages.${system}.default;

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
