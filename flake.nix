{
  description = "nixpkgs with the unfree bits enabled";

  inputs = {
    nixpkgs.follows = "nixpkgs-master";
    nixpkgs-master.url = github:NixOS/nixpkgs/master;
    nixpkgs-nixpkgs-unstable.url = github:NixOS/nixpkgs/nixpkgs-unstable;
    nixpkgs-nixos-unstable.url = github:NixOS/nixpkgs/nixos-unstable;
    nixpkgs-release.url = github:NixOS/nixpkgs/nixos-21.11;
  };

  nixConfig = {
    extra-substituters = [
      "https://cuda-maintainers.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let

      inherit (nixpkgs) lib;

      systems = [ "x86_64-linux" ];

      eachSystem = lib.genAttrs systems;

      utils = import ./nix/utils.nix;
      inherit (utils) optionalString;

      x = eachSystem (system:
        import ./nix/jobs.nix {
          inherit system nixpkgs lib;
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

      herculesCI =
        { ref
        , branch
        , tag
        , rev
        , shortRev
        , primaryRepo
        , herculesCI
        }: {
          onPush = { };
          # onPush.default.outputs = {
          #   defaultChecks = self.checks;
          #   neverBreak = x.x86_64-linux.neverBreak;
          # };

          # Cf. https://docs.hercules-ci.com/hercules-ci-agent/evaluation#attributes-herculesCI.onSchedule-when
          onSchedule.neverBreak = {
            when.hour = [ 0 2 20 22 ];
            outputs =
              let
                system = "x86_64-linux";
                cudaCapabilities = [ "8.6" ];
                jobs = import ./nix/jobs.nix {
                  inherit system lib;
                  nixpkgs = inputs.nixpkgs-master;
                  extraConfig = { inherit cudaCapabilities; };
                };
              in
              jobs.neverBreak;
          };

          onSchedule.masterAmpere = {
            when.hour = [ 21 ];
            outputs =
              let
                system = "x86_64-linux";
                cudaCapabilities = [ "8.6" ];
                jobs = import ./nix/jobs.nix {
                  inherit system lib;
                  nixpkgs = inputs.nixpkgs-master;
                  extraConfig = { inherit cudaCapabilities; };
                };
              in
              jobs.checks;
          };

          # Default cudaCapabilities

          onSchedule.nixpkgsUnstableMatrix = {
            when.dayOfWeek = [ "Sat" ];
            outputs =
              let
                system = "x86_64-linux";
                jobs = import ./nix/jobs.nix {
                  inherit system lib;
                  nixpkgs = inputs.nixpkgs-nixpkgs-unstable;
                };
              in
              jobs.checks;
          };
          onSchedule.nixosUnstableMatrix = {
            when.dayOfWeek = [ "Sat" ];
            outputs =
              let
                system = "x86_64-linux";
                jobs = import ./nix/jobs.nix {
                  inherit system lib;
                  nixpkgs = inputs.nixpkgs-nixos-unstable;
                };
              in
              jobs.checks;
          };
        };
    };
}
