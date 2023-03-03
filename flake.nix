{
  description = "nixpkgs with the unfree bits enabled";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
  };

  nixConfig = {
    extra-substituters = [
      "https://cuda-maintainers.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  outputs = inputs@{ self, nixpkgs }:
    let

      inherit (nixpkgs) lib;

      systems = [ "x86_64-linux" ];

      eachSystem = lib.genAttrs systems;

      x = eachSystem (system:
        import ./jobs.nix {
          inherit system inputs lib;
        }
      );
    in
    {
      # Inherit from upstream
      inherit (nixpkgs) lib nixosModules htmlDocs;

      # But replace legacyPackages with the unfree version
      legacyPackages = eachSystem (system: x.${system}.legacyPackages);

      # And load all the unfree+redistributable packages as checks
      checks = eachSystem (system: x.${system}.checks);

      # Expose our own unfree overrides
      overlays = import ./overlays.nix;
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
          onSchedule.writeBranchName.outputs.x86_64-linux =
            let pkgs = self.legacyPackages.x86_64-linux; in
            {
              when.minute = [ 5 10 15 20 25 30 35 40 45 0];
              when.hour = [ 23 0 ];
              branch = pkgs.writeText "branch.txt" ''
                ${branch}: ${rev}
              '';
            };
        };
    };
}
