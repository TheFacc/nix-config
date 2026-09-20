{ inputs, ... }:
{
  imports = [ inputs.catppuccin.homeModules.catppuccin ];

  catppuccin = {
    enable = true;
    autoEnable = false;
    accent = "maroon";
    flavor = "mocha";
  };
}
