let
  f = builtins.getFlake (builtins.toString ./..);
  ci = f.herculesCI { ref = ""; rev = ""; shortRev = ""; tag = ""; primaryRepo = ""; branch = ""; herculesCI = { }; };
  pkgs = f.legacyPackages.${builtins.currentSystem};
  inherit (pkgs) lib;
  utils = import ./utils.nix;

  checks = ci.onSchedule.masterAmpere.outputs;

  paths = lib.mapAttrs (name: drv: builtins.unsafeDiscardStringContext drv.outPath) checks;
  pathsTxt = builtins.attrValues (lib.mapAttrs (name: path: "${name} -> ${path}") paths);
in
paths
