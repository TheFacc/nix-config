{ ... }:
{
  zramSwap = {
    enable = true;
    # memoryMax = 32768; # this is 32KB
    priority = 50; # default 5
    algorithm = "zstd"; # default zstd
    memoryPercent = 75;
  };
}
