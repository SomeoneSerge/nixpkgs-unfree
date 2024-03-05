let
  allWeek = [
    "Mon"
    "Tue"
    "Wed"
    "Thu"
    "Fri"
    "Sat"
    "Sun"
  ];
in
{
  hci.jobSets = {
    sm_86-cuda-updates-daily = {
      branch = "master";
      jobsAttr = "neverBreak";
      cuda = {
        capabilities = [ "8.6" ];
        forwardCompat = false;
      };
      reason = "reused for nixpkgs-review";
      system = "x86_64-linux";
      when.dayOfWeek = allWeek;
    };
    default-cuda-updates-daily = {
      jobsAttr = "neverBreak";
      reason = "staging mass rebuilds";
      system = "x86_64-linux";
      branch = "master";
      when.dayOfWeek = allWeek;
    };
  };
}
