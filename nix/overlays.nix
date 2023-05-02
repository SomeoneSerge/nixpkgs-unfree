let
  prepareOverlay =
    { isIntel ? false
      # cud(a|nn)Version
      #
      # : Maybe String
      # Semver (<xx.yy> or <xx.yy.zz>) naming
      # the cuda or cudnn revision to set as the default
    , cudaVersion ? null
    , cudnnVersion ? null
      # *mpiProvider*
      #
      # : Maybe String
      # If null: don't touch mpi.
      # If str: names the attribute providing mpi implementation
      # and adds a few MPISupport=true overrides in selected packages
    , mpiProvider ? null
    }:
    final: prev:
    let
      inherit (prev.lib) optionalAttrs versionOlder replaceChars;
      overrideMpi = !(builtins.isNull mpiProvider);
    in
    (
      {
        # These ignore config.cudaSupport in some releases

        openmpi = prev.openmpi.override {
          cudaSupport = true;
        };

        ucx = prev.ucx.override {
          enableCuda = true;
        };

        suitesparse = prev.suitesparse.override {
          enableCuda = true;
        };

      } // optionalAttrs overrideMpi {
        mpi = final.${mpiProvider};

        # Instead of libfabric
        mpich = prev.mpich.override {
          ch4backend = final.ucx;
        };

        # TODO: pythonPackageOverrides
        pytorchMpi = prev.python3Packages.pytorch.override {
          MPISupport = true;
        };
      } // optionalAttrs isIntel {
        blas = prev.blas.override {
          blasProvider = final.mkl;
        };
        lapack = prev.lapack.override {
          lapackProvider = final.mkl;
        };
        opencvWithTbb = prev.opencv.override {
          enableTbb = true;
        };
      } //
      (
        let
          dontOverride = builtins.isNull cudaVersion && builtins.isNull cudnnVersion;

          versionToAttr = v: if builtins.isNull v then "" else "_${replaceChars ["."] ["_"] v}";
          cudaAttr = versionToAttr cudaVersion;
          cudnnAttr = versionToAttr cudnnVersion;

          overlays."21.11" =
            # using prev in assert to avoid infinite recursion
            assert (builtins.isNull cudnnVersion || cudnnVersion == prev."cudnn_cudatoolkit${cudaAttr}");
            {
              cudatoolkit_11 = final."cudatoolkit${cudaAttr}";
              cudatoolkit = final."cudatoolkit${cudaAttr}";
              cudnn = final."cudnn_cudatoolkit${cudaAttr}";
              cutensor = final."cutensor_cudatoolkit${cudaAttr}";
            };
          overlays."22.05" =
            {
              # Assuming Fridh's PR has been merged
              cudaPackages = prev."cudaPackages${cudaAttr}".overrideScope' (final: prev: {
                cudnn = final."cudnn${cudnnAttr}";
              });
            };

          release = prev.lib.version;
          overlay =
            if versionOlder release "21.12" then "21.11"
            else if versionOlder release "22.06" then "22.05"
            else throw "Unsuported nixpkgs release: ${release}";
        in
        optionalAttrs (!dontOverride) overlays.${overlay}
      )
    );
in
{
  # Lexicographic ordering of the names matters for the groupBy in default.nix
  # Overrides that don't change the derivation (compared to basic)
  # won't show up as attributes in the jobset
  # (as long as config's name is lexicographically bigger than "basic")

  basic = prepareOverlay { };

  intel = prepareOverlay {
    isIntel = true;
  };

  # mpich = prepareOverlay {
  #   mpiProvider = "mpich";
  # };

  # openmpi = prepareOverlay {
  #   mpiProvider = "openmpi";
  # };
}
