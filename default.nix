let
  flake = builtins.getFlake (builtins.toString ./.);
  system = builtins.currentSystem;
  output = flake.legacyPackages.${builtins.currentSystem};
in
output
