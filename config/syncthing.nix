{ config, pkgs, ... }:

# TODO set up secrets lol

let
  user = "facc";
in
{
  users.users.${user}.packages = with pkgs; [
    syncthing
  ];

  services.syncthing = {
    enable = true;
    user = "${user}";
    dataDir = "/home/${user}";
    settings = {
	devices = {
	      "Pixel1" = {
      	 	 id = "...";
#      	         compression = "never";
               };
               "Nothing" = {
                 id = "...";
#           	 compression = "never";
               };
    	}; 
        folders = {
      		# walls
      		"/home/${user}/OneDrive/scazzo/walls/CellWallCopiesSync/" = {
      		  id = "...";
                  label = "(sync) walls-cell";
       	   	  type = "sendreceive";
        	  devices = [ "Pixel1" "Nothing" ];
                  };
              # screenshots
              "/home/${user}/Pictures/CellScreenshots/" = {
                id = "...";
                label = "(sync) Screenshots(1)";
                type = "sendreceive";
                devices = [ "Nothing" ];
              };
        	 # camera
              # ...
              };
    };
    settings.gui = {
      user = "${user}";
      password = "...";
    };
  };  
}
