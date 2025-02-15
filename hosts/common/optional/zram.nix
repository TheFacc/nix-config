{
  zramSwap = {
    enable = true;
    # memoryMax = 32768; # this is 32KB
    memoryPercent = 75; # default 50
    priority = 50; # default 5
    algorithm = "zstd"; # default zstd
  };
}