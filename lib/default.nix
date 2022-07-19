let
  flake = builtins.getFlake (builtins.toString ../.);
in
import "${flake.inputs.nixpkgs}/lib"
