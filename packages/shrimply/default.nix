{
  lib,
  rustPlatform,
  autoAddDriverRunpath,
  autoPatchelfHook,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  clang,
  llvmPackages,
  lld,
  shader-slang,
  skia,
  cudaPackages,
  ffmpeg,
  gtk4,
  gtksourceview5,
  libadwaita,
  libglvnd,
  rubberband,
  boost,
  gdk-pixbuf,
  pango,
  cairo,
  alsa-lib,
  pipewire,
  poppler,
  opencv,
  python3,
  fontconfig,
  freetype,
  icu,
  vulkan-loader,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "shrimply";
  version = "0-unstable-2026-08-30";

  src = fetchFromGitHub {
    owner = "soirihiroka";
    repo = "shrimply";
    rev = "ef453ba674c321cc5590ae0e67dbc2f6dc75b4c9";
    hash = "sha256-3OzavR/nzgxAfhyHQZ/5qiha7Mn80XMAyDnva6GkwM0=";
  };

  cargoHash = "sha256-1bmUerOAOm00oaYfKqSW1x7pTXeNIxdm0YO8KmyEsLU=";

  cudaOxide = fetchFromGitHub {
    owner = "NVlabs";
    repo = "cuda-oxide";
    rev = "b22efa99e8383e2a349c4a3af60d8aa083973890";
    hash = "sha256-NcAjNzc7DMDM21CwWIHnXBB9tocYymW7+Q9Nc/gTKYw=";
  };

  cudaOxideTools = rustPlatform.buildRustPackage {
    pname = "cuda-oxide-tools";
    version = "0.2.1";
    src = finalAttrs.cudaOxide;
    cargoHash = "sha256-zQTTSFhxK6ERd5kJNYS8sKwqvEgMA8nZx3YrammHBbE=";
    doCheck = false;
    buildPhase = ''
      cargo build --release --package cargo-oxide
      # The isolated backend lock can lag the workspace lock.  Use the latter,
      # which is exactly the dependency set vendored by buildRustPackage.
      cp Cargo.lock crates/rustc-codegen-cuda/Cargo.lock
      cargo build --release --lib \
        --manifest-path crates/rustc-codegen-cuda/Cargo.toml \
        --target host-tuple
    '';
    installPhase = ''
      install -Dm755 target/release/cargo-oxide $out/bin/cargo-oxide
      backend=$(find . -type f -name librustc_codegen_cuda.so -print -quit)
      test -n "$backend"
      install -Dm755 "$backend" $out/lib/librustc_codegen_cuda.so
    '';
  };

  vtracer = fetchFromGitHub {
    owner = "visioncortex";
    repo = "vtracer";
    rev = "74c29b1a8c627171c4e7f91c66e2531a35967271";
    hash = "sha256-mgP2kEHsbhJxWBiNZ7DLNaVEaPZMtpIegPIEkgnPC6c=";
  };

  rhubarb = fetchFromGitHub {
    owner = "DanielSWolf";
    repo = "rhubarb-lip-sync";
    rev = "9b9573cd21b253c9ba58739bbd1aa0b50b991bff";
    hash = "sha256-w6TgklwHtwzSHsyz4akT6Nqr/mD8IOGppTMXpikMIHo=";
  };

  skiaSource = fetchFromGitHub {
    owner = "rust-skia";
    repo = "skia";
    rev = "m150-0.98.1";
    hash = "sha256-h/TFrGlqDur7bvIc9CBqDBwSJOQBk0N52/jwle3ay7c=";
  };

  # skia-bindings 0.99.0 requires static Skia m150 archives.  Nixpkgs'
  # component-built Skia 144 provides incompatible shared objects instead.
  skiaM150 = skia.overrideAttrs (old: {
    pname = "skia-m150";
    version = "150-unstable";
    src = finalAttrs.skiaSource;
    gnFlags = (lib.remove "is_component_build=true" old.gnFlags) ++ [
      "is_component_build=false"
      "skia_enable_skparagraph=true"
      "skia_enable_skshaper=true"
    ];
    postInstall = (old.postInstall or "") + ''
      mkdir -p $out/nix-support
      grep -h '^defines = ' obj/{skia,gpu}.ninja \
        obj/modules/{skshaper,skparagraph,skunicode}/*.ninja 2>/dev/null \
        | sed 's/^defines = //' | awk '!seen[$0]++' \
        > $out/nix-support/skia-build-defines
    '';
  });

  optix = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "optix-dev";
    rev = "f1f6dd803f3159992d248178f6e09421c6eb8b6d";
    hash = "sha256-DZqsXSbuvCsh1EXFS29H4zCm20zwBYxVKj/pvZRvSTE=";
  };

  postPatch = ''
    mkdir -p external/{cuda-oxide,vtracer,rhubarb-lip-sync,optix-dev}
    cp -r --no-preserve=mode ${finalAttrs.cudaOxide}/. external/cuda-oxide
    cp -r --no-preserve=mode ${finalAttrs.vtracer}/. external/vtracer
    cp -r --no-preserve=mode ${finalAttrs.rhubarb}/. external/rhubarb-lip-sync
    cp -r --no-preserve=mode ${finalAttrs.optix}/. external/optix-dev
  '';

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    clang
    lld
    python3
    # This workspace links through clang/lld without retaining the ordinary
    # Nix library RPATHs, so reconstruct them from buildInputs at fixup time.
    autoPatchelfHook
    # Add the host NVIDIA driver search path without retaining the build-time
    # libcuda stub as a runtime dependency.
    autoAddDriverRunpath
  ];

  buildInputs = [
    cudaPackages.cudatoolkit
    cudaPackages.libnvjitlink
    finalAttrs.skiaM150
    ffmpeg
    gtk4
    gtksourceview5
    libadwaita
    libglvnd
    rubberband
    boost
    gdk-pixbuf
    pango
    cairo
    alsa-lib
    pipewire
    poppler
    opencv
    fontconfig
    freetype
    icu
    vulkan-loader
  ];

  # libcuda is supplied by the host driver through autoAddDriverRunpath, not
  # by a store path that autoPatchelf can resolve at build time.
  autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];

  env = {
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
    SKIA_SOURCE_DIR = "${finalAttrs.skiaSource}";
    SKIA_LIBRARY_SEARCH_PATH = "${finalAttrs.skiaM150}/lib";
    SKIA_USE_SYSTEM_LIBRARIES = "1";
    OPTIX_ROOT = "${finalAttrs.optix}";
    CUDA_HOME = "${cudaPackages.cudatoolkit}";
    CUDA_TOOLKIT_PATH = "${cudaPackages.cudatoolkit}";
    CUDA_TOOLKIT_TARGET_DIR = "x86_64-linux";
  };

  preBuild = ''
    # skia-bindings needs the compile definitions that correspond to the
    # imported static Skia archives.
    export SKIA_BUILD_DEFINES="$(tr '\n' ' ' < ${finalAttrs.skiaM150}/nix-support/skia-build-defines)"

    # Upstream builds Slang from its submodule.  Recreate its expected layout
    # from Nixpkgs' packaged shader-slang instead.
    mkdir -p "$TMPDIR/slang-source" "$TMPDIR/slang-build/Release"/{bin,lib}
    touch "$TMPDIR/slang-source/CMakeLists.txt"
    ln -s ${shader-slang.dev}/include "$TMPDIR/slang-source/include"
    ln -s ${shader-slang}/bin/slangc "$TMPDIR/slang-build/Release/bin/slangc"
    ln -s ${shader-slang}/lib/* "$TMPDIR/slang-build/Release/lib/"
    export SLANG_SOURCE_DIR="$TMPDIR/slang-source"
    export SLANG_BUILD_DIR="$TMPDIR/slang-build"

    # The host crates embed eight sm_86 CUBINs with include_bytes!.  Upstream's
    # documented build generates them before compiling the editor.
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    # Device crates are still linked as host binaries while cargo-oxide
    # extracts their GPU artifacts, so make the sandbox's CUDA driver stub
    # available to the linker.
    export NIX_LDFLAGS="$NIX_LDFLAGS -L${cudaPackages.cudatoolkit}/lib/stubs -lwebpdemux"
    export LIBNVVM_PATH="${cudaPackages.cudatoolkit}/nvvm/lib/libnvvm.so"
    export LD_LIBRARY_PATH="${cudaPackages.cudatoolkit}/lib/stubs:${lib.getLib cudaPackages.libnvjitlink}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export PATH="${finalAttrs.cudaOxideTools}/bin:$PATH"
    export CUDA_OXIDE_BACKEND="${finalAttrs.cudaOxideTools}/lib/librustc_codegen_cuda.so"
    make cuda-artifacts CARGO=cargo CUDA_OXIDE_TARGET=sm_86
  '';

  buildPhase = ''
    runHook preBuild
    cargo build --release \
      --package shrimply-editor-ui \
      --package shrimply-launcher-ui
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # The launcher owns the public command and starts the editor after a
    # project is selected.  Keep the sibling name expected by launch_editor().
    install -Dm755 target/release/shrimply $out/bin/shrimply
    install -Dm755 target/release/shrimply-editor $out/bin/shrimply-editor
    install -Dm644 assets/dev.shrimply.Shrimply.desktop \
      $out/share/applications/dev.shrimply.Shrimply.desktop
    install -Dm644 assets/icons/dev.shrimply.Shrimply.svg \
      $out/share/icons/hicolor/scalable/apps/dev.shrimply.Shrimply.svg

    runHook postInstall
  '';

  meta = {
    description = "Video editor for creating videos from start to finish";
    homepage = "https://github.com/soirihiroka/shrimply";
    license = lib.licenses.gpl3Plus;
    mainProgram = "shrimply";
    platforms = lib.platforms.linux;
  };
})
