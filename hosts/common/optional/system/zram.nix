{ config, lib, ... }: lib.mkMerge [

  {
    zramSwap = {
      enable = true;
      # memoryMax = 32768; # this is 32KB
      priority = 50; # default 5
      algorithm = "zstd"; # default zstd
    };
  }
  
  # set amount based on hostname
  (lib.mkIf (config.networking.hostName == "nixook") {
    zramSwap.memoryPercent = 200; # full degen zram - 8GB physical and 16GB virtual yay
  })
  (lib.mkIf (config.networking.hostName != "nixook") {
    zramSwap.memoryPercent = 75; # default
  })
]
