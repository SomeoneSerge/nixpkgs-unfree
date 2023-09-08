# FIXME: make filter-jobs.nix instead, and import nixpkgs in the flake

{ system ? builtins.currentSystem
, nixpkgs ? (builtins.getFlake (builtins.toString ./.)).inputs.nixpkgs
, extraConfig ? { }
, lib ? nixpkgs.lib
, debug ? false
}:
let
  utils = import ./utils.nix { inherit debug; };

  inherit (utils)
    maybeBuildable
    isSupportedCuPackage
    ;

  overlays = import ./overlays.nix;
  nixpkgsInstances = lib.mapAttrs
    (configName: overlay: import nixpkgs ({
      inherit system;
      config = {
        allowUnfree = true;
        cudaSupport = true;
      } // extraConfig;
      overlays = [ overlay ];
    }))
    overlays;

  neverBreakExtra = [
    # Messy, but vital to keep cached:
    [ "blender" ]
    [ "colmapWithCuda" ]
    [ "faiss" ]
    [ "tts" ]
  ];

  extraPackages = neverBreakExtra ++ [
    [ "blas" ]
    [ "cudnn" ]
    [ "lapack" ]
    [ "mpich" ]
    [ "nccl" ]
    [ "opencv" ]
    [ "openmpi" ]
    [ "ucx" ]

    [ "cctag" ] # Failed in https://github.com/NixOS/nixpkgs/pull/233581
    [ "cholmod-extra" ]
    [ "gpu-screen-recorder" ]
    [ "lightgbm" ]
    [ "monado" ] # Failed in https://github.com/NixOS/nixpkgs/pull/233581
    [ "obs-studio-plugins" "obs-backgroundremoval" ]
    [ "openmvg" ]
    [ "openmvs" ]
    [ "opentrack" ]
    [ "openvino" ]
    [ "pixinsight" ] # Failed in https://github.com/NixOS/nixpkgs/pull/233581
    [ "rtabmap" ]
    [ "suitesparse" ]
    [ "truecrack-cuda" ]
    [ "xgboost" ]
    [ "wyoming-faster-whisper" ]

    # GUI and similar mess, but desirable to have in cache:
    [ "deepin" "image-editor" ] # Failed in https://github.com/NixOS/nixpkgs/pull/233581
    [ "ffmpeg-full" ]
    [ "gimp" ]
    [ "gst_all_1" "gst-plugins-bad" ]
    [ "meshlab" ]
    [ "qgis" ]
    [ "saga" ]
    [ "ueberzugpp" ] # Failed in https://github.com/NixOS/nixpkgs/pull/233581

    [ "linuxPackages" "nvidia_x11" ]
    [ "linuxPackages" "nvidia_x11_beta" ]
    [ "linuxPackages" "nvidia_x11_beta_open" ]
    [ "linuxPackages" "nvidia_x11_vulkan_beta_open" ]
  ];

  pythonAttrs =
    let
      matrix = lib.cartesianProductOfSets
        {
          pkg = [
            "Keras"
            "TheanoWithCuda"
            "boxx"
            "bpycv"
            "caffe"
            "catboost"
            "chainer"
            "cupy"
            "faiss"
            "ffmpeg-full"
            "flax"
            "functorch"
            "gpt-2-simple"
            "grad-cam"
            "jax"
            "jaxlib"
            "jaxlib"
            "kornia"
            "libgpuarray"
            "mmcv"
            "mxnet"
            "noisetorch"
            "onnx"
            "openai-triton"
            "openai-whisper"
            "opencv4"
            "pycuda"
            "pyrealsense2WithCuda"
            "pytorch"
            "pytorch-lightning"
            "scikit-learn" # makes sure it's cached with MKL
            "scikitimage"
            "spacy-transformers"
            "tensorflow-probability"
            "tensorflowWithCuda"
            "tesserocr"
            "tiny-cuda-nn"
            "torch"
            "torchaudio"
            "torchvision"
            "transformers"
            "tts"
            "vidstab"
          ] ++ [
            # These need to be rebuilt because of MKL
            "numpy"
            "scipy"
          ];
          ps = [
            "python3Packages"
            # "python310Packages"
            # "python311Packages"
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
          (builtins.attrNames (lib.filterAttrs isSupportedCuPackage nixpkgs.cudaPackages));
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
            jobName = lib.concatStringsSep "." ([ cfg ] ++ path);
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

      inherit (utils) dedupOutpaths;
    in
    lib.listToAttrs (dedupOutpaths kvPairs);

  # List packages that we never want to be even marked as "broken"
  # These will be checked just for x86_64-linux and for one release of python
  neverBreak =
    let
      pkgs = nixpkgsInstances.basic;
      cuPackages = lib.attrNames (
        lib.filterAttrs isSupportedCuPackage
          pkgs.cudaPackages
      );
      latestPython = "python3Packages";
      pyPackages = [
        "imageio-ffmpeg"
        "jax"
        "jaxlib"
        "kornia"
        "opencv4"
        "opensfm"
        "tensorflowWithCuda"
        "torch"
        "torchaudio"
        "torchvision"
      ];
      matrixPy = lib.cartesianProductOfSets {
        pkg = pyPackages;
        ps = [ latestPython ];
      };
      matrixCu = lib.cartesianProductOfSets {
        pkg = cuPackages;
        ps = [ "cudaPackages" ];
      };
      mkPath = { pkg, ps }: [ ps pkg ];
      matrix =
        neverBreakExtra ++
        builtins.map
          mkPath
          (matrixPy ++ matrixCu);
      jobs = builtins.concatMap
        (path:
          let
            jobName = lib.concatStringsSep "." path;
            package = lib.attrByPath path [ ] pkgs;
          in
          assert builtins.isList path;
          assert builtins.isString (builtins.head path);
          [{ inherit jobName package; }])
        matrix;
      kvPairs = builtins.map
        ({ jobName, package }: lib.nameValuePair jobName package)
        jobs;
    in
    assert builtins.isList matrix;
    (lib.listToAttrs kvPairs);
in
{
  # Export the whole tree
  legacyPackages = nixpkgsInstances.basic;

  # Returns the recursive set of unfree but redistributable packages as checks
  inherit checks neverBreak;
}
