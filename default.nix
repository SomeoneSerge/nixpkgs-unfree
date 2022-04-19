let
  defaultConfig = { allowUnfree = true; cudaSupport = true; };
in

{ config ? defaultConfig, ... }@userArgs:

let
  flake = builtins.getFlake (builtins.toString ./.);
  system = builtins.currentSystem;

  args = userArgs // { inherit config; };
  newInstance = import flake.inputs.nixpkgs args;
  defaultOutput = flake.legacyPackages.${builtins.currentSystem};
  spawn1000Instances = !(args == { config = defaultConfig; });
in
if spawn1000Instances then newInstance else defaultOutput
