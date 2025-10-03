{ inputs, ... }:
{
  imports = [ inputs.catppuccin.nixosModules.catppuccin ];

  catppuccin = {
    accent = "maroon";
    flavor = "mocha";
  };
}