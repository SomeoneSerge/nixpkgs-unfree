{
  hci.jobSets.pytorch-default-master-daily-neverBreak = {
    branch = "master";
    jobsAttr = "neverBreak";
    reason = "daily pytorch&c build";
    system = "x86_64-linux";
    when.hour = [ 3 ];
  };
}
