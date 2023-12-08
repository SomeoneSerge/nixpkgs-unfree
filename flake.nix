{
  description = "nixpkgs with the unfree bits enabled";

  inputs = {
    nixpkgs.follows = "nixpkgs-master";

    # Which revisions to build, NB the nixpkgs-$branch pattern
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-release.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs-release-staging.url = "github:NixOS/nixpkgs/staging-23.11";

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
    extra-substituters = [
      "https://cuda-maintainers.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  outputs = inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; }
      {
        imports = [
          inputs.hercules-ci-effects.flakeModule
          ./nix/ci
        ];
        systems = [ "x86_64-linux" ];
        hercules-ci.flake-update = {
          enable = true;
          when = {
            minute = 30;
            hour = [ 2 7 12 17 22 ];
          };
          autoMergeMethod = "rebase";

          # Don't create PRs in flake-update, instead push to master
          createPullRequest = false;
          updateBranch = "develop";
        };
        flake =
          let

            inherit (inputs) nixpkgs;
            inherit (nixpkgs) lib;

            systems = [ "x86_64-linux" ];

            eachSystem = lib.genAttrs systems;

            x = eachSystem (system:
              import ./nix/jobs.nix {
                inherit system nixpkgs lib;
                extraConfig.cudaCapabilities = [ "7.0" "8.0" "8.6" ];
                extraConfig.cudaEnableForwardCompat = false;
              }
            );
          in
          {
            # Inherit from upstream
            inherit (nixpkgs) lib; # nixosModules htmlDocs;

            # But replace legacyPackages with the unfree version
            legacyPackages = eachSystem (system: x.${system}.legacyPackages);

            # And load all the unfree+redistributable packages as checks
            checks = eachSystem (system: x.${system}.neverBreak);

            # Expose our own unfree overrides
            overlays = import ./nix/overlays.nix;
            overlay = self.overlays.basic;
          };
      };
}
