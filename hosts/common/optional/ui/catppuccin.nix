{ inputs, ... }:
{
  imports = [ inputs.catppuccin.nixosModules.catppuccin ];

  catppuccin = {
    enable = true;
    autoEnable = false;
    accent = "maroon";
    flavor = "mocha";
  };
}