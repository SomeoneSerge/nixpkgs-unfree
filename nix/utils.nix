{ debug ? false
}:
rec {
  optionalString = cond: str: if cond then str else "";

  # nixpkgs' lib.lists.toList
  ensureList = x: if builtins.isList x then x else [ x ];

  # Copy-paste from nixpkgs
  hasPrefix =
    # Prefix to check for
    pref:
    # Input string
    str: builtins.substring 0 (builtins.stringLength pref) str == pref;


  trace = if debug then builtins.trace else (msg: value: value);

  # cf. Tweaked version of nixpkgs/maintainers/scripts/check-hydra-by-maintainer.nix
  maybeBuildable = v:
    let result = builtins.tryEval
      (
        if isDerivation v then
        # Skip packages whose closure fails on evaluation.
        # This happens for pkgs like `python27Packages.djangoql`
        # that have disabled Python pkgs as dependencies.
          builtins.seq v.outPath [ v ]
        else [ ]
      );
    in if result.success then result.value else [ ];

  # removed packages (like cudatoolkit_6) are just aliases that `throw`:
  notRemoved = pkg: (builtins.tryEval (builtins.seq pkg true)).success;

  isUnfreeRedistributable = licenses:
    builtins.any (l: (!l.free or true) && (l.redistributable or false)) licenses;

  hasLicense = pkg:
    pkg ? meta.license;

  hasUnfreeRedistributableLicense = pkg:
    hasLicense pkg &&
    isUnfreeRedistributable (ensureList pkg.meta.license);

  isDerivation = a: a ? type && a.type == "derivation";

  # Picking out the redist parts of cuda
  # and specifically ignoring the runfile-based cudatoolkit
  cuPrefixae = [
    "cudnn"
    "cutensor"
    "cuda_"
    "cuda-"
    "libcu"
    "libnv"
    "libnpp"
    "nccl"
    "nsight_systems"
    "nsight_compute"
    "nvidia_"
    "tensorrt"
  ];
  unsupportedCuPackages = [
    "cuda-samples"
    "nvidia_driver"
    "tensorrt"
    "tensorrt_8_4_0"
  ];
  isCuPackage = name: drv:
    (notRemoved drv)
    && (isDerivation drv)
    && (builtins.any (p: hasPrefix p name) cuPrefixae);
  isSupportedCuPackage = name: drv: (isCuPackage name drv) && !builtins.elem name unsupportedCuPackages;

  dedupOutpaths = nameDrvPairs:
    let
      outPathToPair = builtins.groupBy (pair: (builtins.unsafeDiscardStringContext pair.value.outPath)) nameDrvPairs;
      groupedPairs = builtins.attrValues outPathToPair;
      uniquePairs = builtins.map builtins.head groupedPairs;
    in
    uniquePairs;
}
