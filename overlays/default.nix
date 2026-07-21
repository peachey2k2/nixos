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
    pi = inputs.llm-agents.packages.${system}.pi;
    antigravity-cli = inputs.llm-agents.packages.${system}.antigravity-cli;
    comfyui = inputs.comfyui.packages.${system}.cuda;
    nilshell = inputs.nilshell.packages.${system}.default;
  })
]
