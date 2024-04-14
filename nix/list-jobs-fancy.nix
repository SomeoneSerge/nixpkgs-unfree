let
  f = builtins.getFlake (builtins.toString ./..);
  ci = f.herculesCI { };
  pkgs = f.legacyPackages.${builtins.currentSystem};
  inherit (pkgs) lib;
  utils = import ./utils.nix;

  checks = ci.onSchedule.buildMasterAmpereMatrix.outputs;
  paths = lib.mapAttrs (
    name: drv: "${name} -> ${builtins.unsafeDiscardStringContext drv.outPath}"
  ) checks;
in
paths
