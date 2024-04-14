let
  sm_86-checks = {
    cuda = {
      capabilities = [ "8.6" ];
      forwardCompat = false;
    };
    jobsAttr = "checks";
    reason = "reused for nixpkgs-review";
    system = "x86_64-linux";
  };
  default-checks = {
    jobsAttr = "checks";
    reason = "check";
    system = "x86_64-linux";
  };
in
{
  hci.jobSets = {
    cuda-sm_86-master-daily-neverBreak = sm_86-checks // {
      branch = "master";
      jobsAttr = "neverBreak";
      when.hour = [
        0
        2
        20
        22
      ];
    };
    cuda-sm_86-master-daily-checks = sm_86-checks // {
      branch = "master";
      reason = "daily check";
      when.hour = [ 21 ];
    };
    cuda-sm_86-nixos-unstable-weekly-checks = sm_86-checks // {
      branch = "nixos-unstable";
      when.dayOfWeek = [ "Fri" ];
    };
    cuda-sm_86-nixpkgs-unstable-weekly-checks = sm_86-checks // {
      branch = "nixpkgs-unstable";
      when.dayOfWeek = [ "Sat" ];
    };
    cuda-default-release-staging-weekly-checks = default-checks // {
      branch = "release-staging";
      when.dayOfWeek = [ "Wed" ];
    };
    cuda-default-release-daily-checks = default-checks // {
      branch = "release";
      when = {
        hour = [ 21 ];
      };
    };
    cuda-default-master-weekly-checks = default-checks // {
      branch = "master";
      when = {
        dayOfWeek = [ "Fri" ];
        hour = [ 21 ];
      };
    };
    cuda-default-nixpkgs-unstable-weekly-checks = default-checks // {
      branch = "nixpkgs-unstable";
      when.dayOfWeek = [ "Sat" ];
    };
    cuda-default-nixos-unstable-weekly-checks = default-checks // {
      branch = "nixos-unstable";
      when.dayOfWeek = [ "Sat" ];
    };
  };
}
