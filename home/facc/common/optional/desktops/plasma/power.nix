{ config, ... }:
{
  programs.plasma.powerdevil = {
    general.pausePlayersOnSuspend = true;
    AC = {
      autoSuspend.action = "nothing";
      powerButtonAction = "sleep";
      whenLaptopLidClosed = "doNothing";
      inhibitLidActionWhenExternalMonitorConnected = true;
      dimDisplay = {
        enable = true;
        idleTimeout = 540;
      };
      turnOffDisplay = {
        idleTimeout = 600;
        idleTimeoutWhenLocked = 30;
      };
    };
    battery = {
      powerProfile = "powerSaving"; ##
      autoSuspend.action = "nothing";
      powerButtonAction = "sleep";
      whenLaptopLidClosed = "doNothing";
      inhibitLidActionWhenExternalMonitorConnected = true;
      dimDisplay = {
        enable = true;
        idleTimeout = 60;
      };
      turnOffDisplay = {
        idleTimeout = 90;
        idleTimeoutWhenLocked = 20;
      };
    };
    batteryLevels = {
      criticalAction = "hibernate";
      criticalLevel = 5;
      lowLevel = 10;
    };
    lowBattery = {
      powerProfile = "powerSaving";
      autoSuspend.action = "sleep";
      powerButtonAction = "sleep";
      whenLaptopLidClosed = "doNothing";
      inhibitLidActionWhenExternalMonitorConnected = true;
      displayBrightness = 5; ##
      dimDisplay = {
        enable = true;
        idleTimeout = 20;
      };
      turnOffDisplay = {
        idleTimeout = 30;
        idleTimeoutWhenLocked = 20;
      };
    };
  };
}
