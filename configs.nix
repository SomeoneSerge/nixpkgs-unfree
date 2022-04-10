let
  prepareOverlay =
    { isIntel ? false
    , cudaVersion ? null
    , cudnnVersion ? null
    }:
    final: prev:
    let
      inherit (prev.lib) optionalAttrs versionOlder replaceChars;
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

        mpich = prev.mpich.override {
          ch4backend = final.ucx;
        };

      } // optionalAttrs isIntel {
        blas = prev.blas.override {
          blasProvider = final.mkl;
        };

        lapack = prev.lapack.override {
          lapackProvider = final.mkl;
        };

        # TODO: opencv: enable TBB
      } //
      (
        let
          dontOverride = builtins.isNull cudaVersion && builtins.isNull cudnnVersion;

          versionToAttr = v: if builtins.isNull v then "" else "_${replaceChars ["."] ["_"] v}";
          cudaAttr = versionToAttr cudaVersion;
          cudnnAttr = versionToAttr cudnnVersion;

          overlays."21.11" =
            assert (builtins.isNull cudnnVersion || cudnnVersion == final.cudnn.version);
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

          release = final.lib.nixpkgsVersion;
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
  vanilla = {
    config.allowUnfree = true;
    config.cudaSupport = true;

    overlays = [ (prepareOverlay { }) ];
  };
  intel = {
    config.allowUnfree = true;
    config.cudaSupport = true;

    overlays = [ (prepareOverlay { isIntel = true; }) ];
  };
}
