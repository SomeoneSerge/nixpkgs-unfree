{ system ? builtins.currentSystem
, inputs ? (builtins.getFlake (builtins.toString ./.)).inputs
, lib ? inputs.nixpkgs.lib
, debug ? false
}:
let
  trace = if debug then builtins.trace else (msg: value: value);

  # cf. Tweaked version of nixpkgs/maintainers/scripts/check-hydra-by-maintainer.nix
  maybeBuildable = v:
    let result = builtins.tryEval
      (
        if lib.isDerivation v then
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
    lib.lists.any (l: (!l.free or true) && (l.redistributable or false)) licenses;

  hasLicense = pkg:
    pkg ? meta.license;

  hasUnfreeRedistributableLicense = pkg:
    hasLicense pkg &&
    isUnfreeRedistributable (lib.lists.toList pkg.meta.license);

  isDerivation = a: a ? type && a.type == "derivation";

  # Picking out the redist parts of cuda
  # and specifically ignoring the runfile-based cudatoolkit
  cuPrefixae = [
    "cudnn"
    "cutensor"
    "cuda_"
    "cuda-"
    "lib"
    "nccl"
    "nsight_systems"
    "nsight_compute"
  ];
  isCuPackage = name: drv:
    (notRemoved drv)
    && (isDerivation drv)
    && (builtins.any (p: lib.hasPrefix p name) cuPrefixae);

  overlays = import ./overlays.nix;
  nixpkgsInstances = lib.mapAttrs
    (configName: overlay: import inputs.nixpkgs ({
      inherit system;
      config.allowUnfree = true;
      config.cudaSupport = true;
      overlays = [ overlay ];
    }))
    overlays;

  extraPackages = [
    [ "blas" ]
    [ "cudnn" ]
    [ "lapack" ]
    [ "mpich" ]
    [ "nccl" ]
    [ "opencv" ]
    [ "openmpi" ]
    [ "ucx" ]

    [ "suitesparse" ]
    [ "cholmod-extra" ]
    [ "truecrack-cuda" ]
    [ "gpu-screen-recorder" ]
    [ "xgboost" ]
    [ "faiss" ]

    # Messy, but vital to keep cached:
    [ "blender" ]
    [ "colmapWithCuda" ]
    [ "opensfm" ]

    # GUI and similar mess, but desirable to have in cache:
    [ "meshlab" ]
    [ "qgis" ]
    [ "ffmpeg-full" ]
    [ "gst_all_1" "gst-plugins-bad" ]
    [ "gimp" ]
  ];

  pythonAttrs =
    let
      matrix = lib.cartesianProductOfSets
        {
          pkg = [
            "caffe"
            "chainer"
            "cupy"
            "catboost"
            "faiss"
            "jaxlib"
            "Keras"
            "libgpuarray"
            "mxnet"
            "onnx"
            "opencv4"
            "torch"
            "pytorch"
            "pytorch-lightning"
            "functorch"
            "pycuda"
            "pyrealsense2WithCuda"
            "torchvision"
            "jaxlib"
            "jax"
            "flax"
            "TheanoWithCuda"
            "tensorflowWithCuda"
            "tensorflow-probability"
            # makes sure it's cached with MKL
            "scikit-learn"
            "scikitimage"
          ] ++ [
            # These need to be rebuilt because of MKL
            "numpy"
            "scipy"
          ];
          ps = [
            # TODO: 2022-10-03: python3 = python310 already in nixpkgs-unstable; consider dropping python39 cache
            "python39Packages"
            "python310Packages"
          ];
        };

      mkPath = { pkg, ps }: [ ps pkg ];
    in
    builtins.map
      mkPath
      matrix;

  hasFridhPR = nixpkgs: nixpkgs.cudaPackages ? "overrideScope'";

  cudaPackages = lib.concatMap
    (cfg:
      let
        nixpkgs = nixpkgsInstances.${cfg};
        jobs = builtins.map
          (pkg: {
            inherit cfg; path = [ "cudaPackages" pkg ];
          })
          (builtins.attrNames (lib.filterAttrs isCuPackage nixpkgs.cudaPackages));
      in
      if hasFridhPR nixpkgs then jobs else [ ]
    )
    (builtins.attrNames overlays);

  checks =
    let
      matrix = lib.cartesianProductOfSets
        {
          cfg = builtins.attrNames overlays;
          path = extraPackages ++ pythonAttrs;
        }
      ++ cudaPackages;
      supported = builtins.concatMap
        ({ cfg, path }:
          let
            jobName = lib.concatStringsSep "_" ([ cfg ] ++ path);
            package = lib.attrByPath path [ ] nixpkgsInstances.${cfg};
            mbSupported = maybeBuildable package;
          in
          if mbSupported == [ ]
          then [ ]
          else [{ inherit jobName; package = (builtins.head mbSupported); }])
        matrix;
      kvPairs = builtins.map
        ({ jobName, package }: lib.nameValuePair jobName package)
        supported;

      dedupOutpaths = nameDrvPairs:
        let
          outPathToPair = lib.groupBy (pair: (builtins.unsafeDiscardStringContext pair.value.outPath)) nameDrvPairs;
          groupedPairs = builtins.attrValues outPathToPair;
          uniquePairs = builtins.map builtins.head groupedPairs;
        in
        uniquePairs;
    in
    lib.listToAttrs (dedupOutpaths kvPairs);

  # List packages that we never want to be even marked as "broken"
  # These will be checked just for x86_64-linux and for one release of python
  neverBreak =
    let
      pkgs = nixpkgsInstances.basic;
      cuPackages = lib.filterAttrs isCuPackage pkgs.cudaPackages;
      stablePython = "python310Packages";
      pyPackages = lib.genAttrs [
        "torch"
        "torchvision"
        "jaxlib"
        "tensorflowWithCuda"
      ]
        (name: pkgs.${stablePython}.${name});
    in
    pyPackages // cuPackages;
in
{
  # Export the whole tree
  legacyPackages = nixpkgsInstances.basic;

  # Returns the recursive set of unfree but redistributable packages as checks
  inherit checks neverBreak;
}
