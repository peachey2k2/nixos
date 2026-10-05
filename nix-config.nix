{
  experimental-features = [
    "flakes"
    "nix-command"
    "pipe-operators"
    "cgroups"
  ];

  extra-substituters = [
    "https://cache.nixos.org/"
    "https://cache.numtide.com"
    "https://comfyui.cachix.org"
    "https://nix-community.cachix.org"
    "https://cache.iog.io"
    "https://nixpkgs-unfree.cachix.org"
    "https://cache.nixos-cuda.org"
    "https://kopuz.cachix.org"
    "https://cache.tuwunel.chat"
    "https://tuwunel.cachix.org"
  ];

  extra-trusted-public-keys = [
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    "kopuz.cachix.org-1:J2X3AnAYhKTJW5S3aCLoA1ckonQXVNZMQvhZA0YAufw="
    "cache.tuwunel.chat-1:ZafUaXiRMozDa9N2SWim6EdzH0EEjWjwfvlTxXvcjLA="
    "tuwunel.cachix.org-1:VRecUeDcaPxtYDA6bnMF3snPM7VYX8K605z4uuG2nWc="
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
  max-jobs = "auto";
  cores = 0;
}
