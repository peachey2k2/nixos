{
  lib,
  buildNpmPackage,
  bun,
  fd,
  fetchurl,
  makeWrapper,
  ripgrep,
  src,
}:

let
  package = lib.importJSON "${src}/packages/coding-agent/package.json";
  modelDataArchive = fetchurl {
    url = "https://github.com/earendil-works/pi/releases/download/v${package.version}/pi-${package.version}-source.tar.gz";
    hash = "sha256-5GZ88KpY6vNLSCMsKqPFP6M8dxRVIkzMgisl3fFneAg=";
  };
in
buildNpmPackage {
  pname = "pi-alternate";
  inherit (package) version;
  inherit src;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-3KBscSw5vpBuTd9QkR60AW2+5Lycj/HrIa+8Uhid0CE=";
  npmRebuildFlags = [ "--ignore-scripts" ];
  makeCacheWritable = true;

  npmBuildScript = "build:offline";

  preBuild = ''
    model_data_dir="$TMPDIR/pi-model-data"
    mkdir -p "$model_data_dir"
    tar -xzf ${modelDataArchive} -C "$model_data_dir"
    model_data_root="$model_data_dir/pi-${package.version}"

    cp "$model_data_root/packages/ai/src/models.generated.ts" packages/ai/src/
    cp "$model_data_root/packages/ai/src/image-models.generated.ts" packages/ai/src/
    cp -r "$model_data_root/packages/ai/src/providers/data" packages/ai/src/providers/
  '';

  nativeBuildInputs = [
    bun
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    build_dir="$TMPDIR/pi-alternate"
    sh ./scripts/build-binaries.sh \
      --skip-install \
      --skip-deps \
      --skip-build \
      --platform linux-x64 \
      --out "$build_dir"

    package_dir="$out/libexec/pi"
    mkdir -p "$out/bin" "$package_dir"
    cp -r "$build_dir/linux-x64/." "$package_dir/"

    makeWrapper "$package_dir/pi" "$out/bin/pi" \
      --prefix PATH : ${
        lib.makeBinPath [
          fd
          ripgrep
        ]
      } \
      --set PI_PACKAGE_DIR "$package_dir" \
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0

    runHook postInstall
  '';

  meta = {
    description = "Pi coding agent using an alternate-screen transcript viewport";
    homepage = "https://github.com/cope-hq/pi-alternate";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pi";
  };
}
