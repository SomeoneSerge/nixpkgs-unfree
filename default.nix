{ system ? builtins.currentSystem
, inputs ? (builtins.getFlake (builtins.toString ./.)).inputs
, lib ? inputs.nixpkgs.lib
, debug ? false
}:
let
  trace = if debug then builtins.trace else (msg: value: value);
  # Tweaked version of nixpkgs/maintainers/scripts/check-hydra-by-maintainer.nix
  #
  # It traverses nixpkgs recursively, respecting recurseForDerivations and 
  # returns a list of name/value pairs of all the packages matching "cond"
  packagesWith = prefix: cond: set:
    lib.flatten
      (lib.mapAttrsToList
        (key: v:
          let
            name = "${prefix}${key}";
            result = builtins.tryEval
              (
                if lib.isDerivation v && cond name v then
                # Skip packages whose closure fails on evaluation.
                # This happens for pkgs like `python27Packages.djangoql`
                # that have disabled Python pkgs as dependencies.
                  builtins.seq v.outPath [ (lib.nameValuePair name v) ]
                else if v.recurseForDerivations or false || v.recurseForRelease or false
                # Recurse
                then packagesWith "${name}_" cond v
                else [ ]
              );
          in
          if result.success
          then trace name result.value
          else [ ]
        )
        set
      )
  ;

  isUnfreeRedistributable = licenses:
    lib.lists.any (l: (!l.free or true) && (l.redistributable or false)) licenses;

  hasLicense = pkg:
    pkg ? meta.license;

  hasUnfreeRedistributableLicense = pkg:
    hasLicense pkg &&
    isUnfreeRedistributable (lib.lists.toList pkg.meta.license);

  configs = import ./configs.nix;
  nixpkgsInstances = lib.mapAttrs
    (configName: config: import inputs.nixpkgs ({ inherit system; } // config))
    configs;
  supportedPackages = lib.mapAttrs (cfgName: pkgs: packagesWith "" (_: _: true) pkgs) nixpkgsInstances;

  extraPackages = [
    [ "blas" ]
    [ "cudatool]kit" ]
    [ "lapack" ]
    [ "mpich" ]
    [ "openmpi" ]
    [ "ucx" ]
    [ "blender" ]
    [ "colmapWithCuda" ]
  ];

  pythonAttrs =
    let
      matrix = lib.cartesianProductOfSets
        {
          pkg = [
            "opencv"
            "jaxlib"
            "pytorch"
            "tensorflowWithCuda"
          ];
          ps = [
            "python38Packages"
            "python39Packages"
            "python310Packages"
          ];
        };

      mkPath = { pkg, ps }: [ ps pkg ];
    in
    builtins.map
      mkPath
      matrix;

  checks =
    let
      matrix = lib.cartesianProductOfSets
        {
          cfg = builtins.attrNames configs;
          path = extraPackages ++ pythonAttrs;
        };
      maybeSupported = builtins.map
        ({ cfg, path }:
          let
            jobName = lib.concatStringsSep "_" ([ cfg ] ++ path);
            mbPackage = lib.attrByPath path [ ] supportedPackages.${cfg};
          in
          { inherit jobName mbPackage; })
        matrix;
      nonempty = builtins.concatMap
        ({ jobName, mbPackage }:
          if mbPackage == [ ]
          then [ ]
          else [{ inherit jobName; package = builtins.head mbPackage; }])
        maybeSupported;
      kvPairs = builtins.map
        ({ jobName, mbPackage }: lib.nameValuePair jobName mbPackage)
        nonempty;
    in
    lib.listToAttrs kvPairs;
in
{
  # Export the whole tree
  legacyPackages = nixpkgsInstances.vanilla;

  # Returns the recursive set of unfree but redistributable packages as checks
  inherit checks;
}
