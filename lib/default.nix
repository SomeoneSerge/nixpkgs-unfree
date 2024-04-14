let
  lockFile = builtins.fromJSON (builtins.readFile ../flake.lock);
  nixpkgsNodeName = lockFile.nodes.root.inputs.nixpkgs;
  nixpkgsNode = lockFile.nodes.${nixpkgsNodeName};
  nixpkgs =
    with nixpkgsNode;
    builtins.fetchGit {
      url = "https://github.com/${locked.owner}/${locked.repo}.git";
      rev = locked.rev;
      ref = original.ref;
    };
in
assert nixpkgsNode.locked.type == "github";
import "${nixpkgs}/lib"
