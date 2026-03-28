{ pkgs, lib, ... }:

{
  environment.systemPackages = [
    (pkgs.buildGoModule {
      pname = "notesmd-cli";
      version = "0.3.4"; # 260313

      src = pkgs.fetchFromGitHub {
        owner = "Yakitrak";
        repo = "notesmd-cli";
        rev = "b58227d0ffaa06eb7880ba7cd16561111deda79d";
        hash = "sha256-sZKyXDgDuJI7cFIMQl1w2Ir92HmhZ1Vhz7FUoEkn3Mo="; # lib.fakeHash
      };
      vendorHash = null;

      meta = with lib; {
        description = "Ineract with Obsidian notes through CLI (no need for Obsidian)";
        homepage = "https://github.com/Yakitrak/notesmd-cli";
        license = licenses.mit; # adjust if needed
        platforms = platforms.linux;
      };
    })
  ];

  # N8N connection
  services.n8n = {
    environment = {
        NODES_EXCLUDE = "[]"; # enable ExecuteCommand for notesmd-cli
    };
  };
}
