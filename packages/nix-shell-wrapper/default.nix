with import <nixpkgs> {};
stdenvNoCC.mkDerivation {
  name = "nix-shell-wrapper";

  script = substituteAll {
    src = ./nix-shell-wrapper;
    inherit zsh bashInteractive;
  };

  phases = ["installPhase"];

  installPhase = "install $script $out";
}
