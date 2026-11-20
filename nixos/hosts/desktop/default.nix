# Desktop host: AMD Ryzen + NVIDIA RTX 3090.
{ config, pkgs, zen-browser, ... }:

let
  zen-browser-pkg = zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core.nix
    ../../modules/desktop.nix
    ../../modules/hardware-amd.nix
    ../../modules/hardware-nvidia.nix
  ];

  networking.hostName = "nixos-desktop";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Desktop cache/swap tuning.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  boot.kernel.sysctl = {
    "vm.vfs_cache_pressure" = 50;
    "vm.swappiness" = 100;
    "vm.max_map_count" = 2147483642;
    "net.core.default_qdisc" = "cake";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  users.users.rambeau.extraGroups = [
    "networkmanager"
    "wheel"
    "docker"
    "libvirtd"
    "i2c"
  ];

  # Desktop features that are safe to keep host-specific.
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];

  programs.gamemode.enable = true;
  environment.systemPackages = with pkgs; [
    hydralauncher
    nirimon
    nirius
    opencode
    vicinae
    spotify
    spicetify-cli
    zen-browser-pkg
  ];

  programs.gamemode.settings = {
    general.renice = 10;
    cpu = {
      desiredgov = "performance";
      defaultgov = "powersave";
    };
  };
}
