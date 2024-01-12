{
  config,
  inputs,
  lib,
  withSystem,
  ...
}:
let
  inherit (lib) attrsets types;
  inherit (lib.options) mkOption;
in
{
  imports = [
    ./aalto.nix
    ./cuda-jetson.nix
    ./cuda-x86_64-linux.nix
    ./pytorch.nix
    ./whisper.nix
    ./cuda-updates.nix
  ];
  options.hci.jobSets = mkOption {
    description = "Job sets to build";
    type = types.attrsOf (
      types.submodule {
        options = {
          branch = mkOption {
            description = "The branch to build";
            type = types.enum [
              "master"
              "nixos-unstable"
              "nixpkgs-unstable"
              "release"
              "release-staging"
            ];
          };
          cuda = {
            capabilities = mkOption {
              description = ''
                List of CUDA capabilities to build for.
                If empty, the default capabilities are used.
              '';
              default = [];
              type = types.listOf types.nonEmptyStr;
            };
            forwardCompat = mkOption {
              description = "Whether to enable forward compatibility for CUDA";
              default = true;
              type = types.bool;
            };
          };
          jobsAttr = mkOption {
            description = "The attribute set to build";
            type = types.enum [
              "neverBreak"
              "checks"
            ];
          };
          reason = mkOption {
            description = "The reason for building";
            type = types.nonEmptyStr;
          };
          system = mkOption {
            description = "The system to build for";
            type = types.enum [
              "x86_64-linux"
              "aarch64-linux"
            ];
          };
          when = (import "${inputs.hercules-ci-effects}/flake-modules/types/when.nix" {inherit lib;}).option;
        };
      }
    );
  };
  config.herculesCI = {
    onSchedule =
      let
        mkOnScheduleEntry =
          {
            branch,
            cuda,
            jobsAttr,
            reason,
            system,
            when,
          }:
          let
            jobs = import ../jobs.nix {
              inherit system;
              nixpkgs = inputs."nixpkgs-${branch}";
              extraConfig = {
                allowUnfree = true;
                cudaSupport = true;
                cudaEnableForwardCompat = cuda.forwardCompat;
              } // attrsets.optionalAttrs (cuda.capabilities != []) {cudaCapabilities = cuda.capabilities;};
            };
          in
          {
            inherit when;
            outputs = jobs.${jobsAttr};
          };
      in
      attrsets.mapAttrs (_: mkOnScheduleEntry) config.hci.jobSets;
    onPush.default.outputs = {
      effects = withSystem "x86_64-linux" (
        {hci-effects, pkgs, ...}:
        {
          releaseBranch = hci-effects.modularEffect {
            imports = [../../effects/git-push/effects-fun.nix];
            git.push = {
              source = {
                url = "https://github.com/NixOS/nixpkgs.git";
                ref = inputs.nixpkgs-master.rev;
              };
              destination = {
                url = "https://github.com/9d80dba85131ab22/nixpkgs.git";
                ref = "buildNixosUnstable80";
                tokenSecret = "nixpkgCuda";
              };
            };
          };
        }
      );
    };
  };
}
