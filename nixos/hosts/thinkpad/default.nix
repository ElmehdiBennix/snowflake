# ThinkPad host placeholder.
# Replace hardware-configuration.nix with the output of nixos-generate-config
# before switching the laptop to this host.
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core.nix
    ../../modules/desktop.nix
  ];

  networking.hostName = "nixos-thinkpad";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Laptop power management defaults.
  services.upower.enable = true;

  users.users.rambeau.extraGroups = [
    "networkmanager"
    "wheel"
  ];
}
