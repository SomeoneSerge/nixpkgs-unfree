let
  default = {
    branch = "master";
    cuda.forwardCompat = false;
    jobsAttr = "neverBreak";
    system = "aarch64-linux";
  };
  defaultUnstable = default // {
    branch = "nixos-unstable";
  };
in
{
  hci.jobSets = {
    cuda-jetson-orin-master-weekly-neverBreak = default // {
      cuda.capabilities = [ "8.7" ];
      reason = "Jetson Orin";
      when.dayOfWeek = [ "Fri" ];
    };
    cuda-jetson-xavier-master-weekly-neverBreak = default // {
      cuda.capabilities = [ "7.2" ];
      reason = "Jetson Xavier";
      when.dayOfWeek = [ "Fri" ];
    };
    cuda-jetson-tx2-master-weekly-neverBreak = default // {
      cuda.capabilities = [ "6.2" ];
      reason = "Jetson TX2";
      when.dayOfWeek = [ "Fri" ];
    };
    cuda-jetson-nano-master-weekly-neverBreak = default // {
      cuda.capabilities = [ "5.3" ];
      reason = "Jetson Nano";
      when.dayOfWeek = [ "Fri" ];
    };

    # Testing out, for llama.cpp's CI
    cuda-jetson-orin-unstable-weekly-neverBreak = defaultUnstable // {
      cuda.capabilities = [ "8.7" ];
      reason = "Jetson Orin";
      when.dayOfWeek = [ "Fri" ];
    };
    cuda-jetson-xavier-unstable-weekly-neverBreak = defaultUnstable // {
      cuda.capabilities = [ "7.2" ];
      reason = "Jetson Xavier";
      when.dayOfWeek = [ "Fri" ];
    };
    cuda-jetson-tx2-unstable-weekly-neverBreak = defaultUnstable // {
      cuda.capabilities = [ "6.2" ];
      reason = "Jetson TX2";
      when.dayOfWeek = [ "Fri" ];
    };
    cuda-jetson-nano-unstable-weekly-neverBreak = defaultUnstable // {
      cuda.capabilities = [ "5.3" ];
      reason = "Jetson Nano";
      when.dayOfWeek = [ "Fri" ];
    };
  };
}
