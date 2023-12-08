let
  default = {
    cuda = {
      capabilities = [
        "7.0"
        "8.0"
        "8.6"
      ];
      forwardCompat = false;
    };
    reason = "Aalto Triton + RTX3090";
    system = "x86_64-linux";
  };
in
{
  # Aalto Triton + RTX3090
  hci.jobSets = {
    aalto-master-daily-neverBreak = default // {
      branch = "master";
      jobsAttr = "neverBreak";
      when.hour = [
        1
        17
      ];
    };
    aalto-nixos-unstable-daily-neverBreak = default // {
      branch = "nixos-unstable";
      jobsAttr = "neverBreak";
      when.hour = [
        3
        21
      ];
    };
    aalto-nixos-unstable-weekly-checks = default // {
      branch = "nixos-unstable";
      jobsAttr = "checks";
      when.dayOfWeek = ["Sat"];
    };
  };
}
