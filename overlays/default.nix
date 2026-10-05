{
  inputs,
  system,
  nixpkgsConfig,
}:

[
  inputs.fenix.overlays.default
  inputs.run0-sudo-shim.overlays.default

  (final: prev: {
    svlangserver = final.callPackage ../packages/svlangserver { };
    tern = final.callPackage ../packages/tern { };
    marked = final.callPackage ../packages/marked { };
    zynk-cli = final.callPackage ../packages/zynk-cli { };
    zcode = final.callPackage ../packages/zcode { };
    shrimply = final.callPackage ../packages/shrimply { };

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

    # openai 2.53.0 (python3.12 only):
    # tests/test_mtls_http_client.py::test_mtls_example_presents_full_client_chain
    # runs example servers as subprocesses that time out (15s) in the sandbox.
    # Skip just those cases; the rest of the suite passes.
    # NOTE: scoped to python312 via overrideScope on purpose. A global
    # pythonPackagesExtensions would also rewrite python3.14's inline-snapshot,
    # which poisons pydantic -> lief -> nodejs-slim -> the whole system closure
    # (same version, different hash, total cache miss, 6-minute V8 rebuild).
    python312Packages = prev.python312Packages.overrideScope (
      python-final: python-prev: {
        openai = python-prev.openai.overridePythonAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_mtls_example_presents_full_client_chain"
          ];
        });
        # 0.34.2: tests/test_docs.py[categories.md, code_generation.md, testing.md]
        # fail on snapshot formatting drift (black version skew). Upstream-only
        # docs-assertion failures; disable the docs test, keep the rest.
        inline-snapshot = python-prev.inline-snapshot.overridePythonAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [ "test_docs" ];
        });
      }
    );

    # Temporarily disabled: the upstream tokscale test suites are broken.
    tokscale = prev.tokscale.overrideAttrs (_: {
      doCheck = false;
      doInstallCheck = false;
    });

    zen-browser = inputs.zen-browser.packages.${system}.default;
    helium = inputs.helium.packages.${system}.default;
    _0fetch = inputs._0fetch.packages.${system}.default;
    pi = inputs.llm-agents.packages.${system}.pi.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        # Fix chat bar minimum 3 rows (earendil-works/pi#8555):
        # createChatViewport reserves minSize:3 for the editor even when a
        # custom borderless editor renders a single row. Reduce to 1 so
        # single-line input takes 1 row; the default framed editor still
        # sizes to its natural 3 rows (top border + content + bottom border).
        # Patch chat-viewport.js plus the prebundled chunk (hashed filename
        # varies per release, hence grep rather than a fixed path).
        grep -rl 'minSize: *3' dist/modes dist/bundle 2>/dev/null | xargs -r sed -i 's/minSize: *3/minSize: 1/g'
      '';
    });
    omp = inputs.llm-agents.packages.${system}.omp;
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
