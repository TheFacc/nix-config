# Brave browser - minimal config for campiglio user
{
  programs.brave = {
    enable = true;
    commandLineArgs = [
      "--no-default-browser-check"
      "--restore-last-session"
    ];
  };
}