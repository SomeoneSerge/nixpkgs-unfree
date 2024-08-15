{
  description = "nixpkgs with the unfree bits enabled";

  inputs = {
    nixpkgs.follows = "nixpkgs-master";

    # Which revisions to build, NB the nixpkgs-$branch pattern
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-release.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-release-staging.url = "github:NixOS/nixpkgs/staging-24.05";

    hercules-ci-effects = {
      url = "github:hercules-ci/hercules-ci-effects";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [ "https://cuda-maintainers.cachix.org" ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    let
      systems = [ "x86_64-linux" ];
      inherit (inputs) nixpkgs;
      inherit (nixpkgs) lib;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      inherit systems;
      flake =
        let
          eachSystem = lib.genAttrs systems;
          eachBranch = lib.genAttrs [ "master" ];
        in
        {
          herculesCI.onPush.default.outputs = eachSystem (
            system:
            (eachBranch (
              branch:
              import (inputs.nixpkgs + "/pkgs/top-level/release-cuda.nix") {
                inherit system;
                packageSet = import inputs."nixpkgs-${branch}";
              }
            ))
          );
        };
    };
}
