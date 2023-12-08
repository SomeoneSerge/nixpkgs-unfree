{inputs, ...}:
let
  pkgs = import inputs."nixpkgs-nixos-unstable" {
    system = "x86_64-linux";
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = ["5.2"];
    };
  };
in
{
  # Build faster-whisper for 5.2+PTX, weekly
  config.herculesCI.onSchedule.fasterWhisper-5_2-nixos-unstable-weekly = {
    when.dayOfWeek = ["Wed"];
    outputs = {
      torch = pkgs.python3Packages.torch;
      faster-whisper = pkgs.python3Packages.faster-whisper;
      faster-whisper-server = pkgs.wyoming-faster-whisper;
    };
  };
}
