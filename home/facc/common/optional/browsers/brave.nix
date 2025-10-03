{ pkgs, ... }:
{
  # Sadly, few options, unlike firefox. https://discourse.nixos.org/t/how-to-change-browser-specific-settings/32866
  programs.brave = {
    enable = true;
    dictionaries = [
      pkgs.hunspellDictsChromium.en_US
      # pkgs.hunspellDictsChromium.it_IT # not available :/
    ];
    extensions = [
      { id = "hlgbcneanomplepojfcnclggenpcoldo"; } # perplexity
      { id = "ffppmilmeaekegkpckebkeahjgmhggpj"; } # complexity
      { id = "neebplgakaahbhdphmkckjjcegoiijjo"; } # keepa
      { id = "bfidboloedlamgdmenmlbipfnccokknp"; } # purevpn
      { id = "ghbmnnjooekpmoecnnnilnnbdlolhkhi"; } # google docs offline
      { id = "aapbdbdomjkkjkaonfhkkikfgjllcleb"; } # google translate
      { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # sponsorblock
      { id = "nffaoalbilbmmfgbnbgppjihopabppdk"; } # html5 video speed changer
      # { id = "ekhagklcjbdpajgpjgmbionohlpdbjgc"; } # zotero connector
      # { id = "cipccbpjpemcnijhjcdjmkjhmhniiick"; } # scispace copilot
    ];
    # extraOpts = {
    #   # "BrowserSignin" = 0;
    #   # "SyncDisabled" = true;
    #   # "PasswordManagerEnabled" = false;
    #   # "BuiltInDnsClientEnabled" = false;
    #   # "MetricsReportingEnabled" = true;
    #   "SpellcheckEnabled" = true;
    #   "SpellcheckLanguage" = ["it" "en-US"];
    #   # "CloudPrintSubmitEnabled" = false;
    # 
    # EXTRA fatte manualmente, #TODO set declaratively if possible
    # mute default prompt
    # disable brave wallet icon
    # set pinned extensions?
    # };
    commandLineArgs = [
      # "--disable-features=WebRtcAllowInputVolumeAdjustment"
      "--restore-last-session"
      "--enable-features=TouchpadOverscrollHistoryNavigation"
    ];
  };
}
