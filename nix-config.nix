{
  experimental-features = [
    "flakes"
    "nix-command"
    "pipe-operators"
    "cgroups"
  ];

  extra-substituters = [
    "https://cache.nixos.org/"
    "https://nix-community.cachix.org"
    "https://cache.iog.io"
    "https://cuda-maintainers.cachix.org"
    "https://nixpkgs-unfree.cachix.org"
    "https://cache.nixos-cuda.org"
  ];

  extra-trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nqlt0="
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
  ];

  accept-flake-config = true;
  builders-use-substitutes = true;
  flake-registry = "";
  http-connections = 50;
  max-substitution-jobs = 32;
  show-trace = true;
  trusted-users = [ "root" "@build" "@wheel" "@admin" ];
  use-cgroups = true;
  warn-dirty = false;
}
