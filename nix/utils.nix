{ debug ? false
}:
rec {
  optionals = cond: lst: assert builtins.isBool cond; assert builtins.isList lst; if cond then lst else [ ];
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

  # This used to be a tryEval-based routine similar to nixpkgs/maintainers/scripts/check-hydra-by-maintainer.nix
  # Now we only respect `platforms`/`badPlatforms`, not `broken`.
  maybeBuildable = v:
    optionals (isDerivation v && !(v.meta.unsupported or false)) [ v ];

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
    # Requires manually adding trt to /nix/store:
    # "tensorrt"
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
      outPathToPair = builtins.groupBy (pair: (builtins.unsafeDiscardStringContext (builtins.tryEval (builtins.seq pair.value.outPath pair.value.outPath)).result)) nameDrvPairs;
      groupedPairs = builtins.attrValues outPathToPair;
      uniquePairs = builtins.map builtins.head groupedPairs;
    in
    builtins.filter ({ name, value }: name != null) uniquePairs;
}
