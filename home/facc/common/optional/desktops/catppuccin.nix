{ inputs, ... }:
{
  imports = [ inputs.catppuccin.homeModules.catppuccin ];

  catppuccin = {
    accent = "maroon";
    flavor = "mocha";
  };
}
