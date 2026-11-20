# Shared settings for every NixOS machine.
# Host-specific hardware and GPU choices belong in hosts/<name>/ or modules/hardware/.
{ config, pkgs, ... }:

{
  # Modern Nix commands and flakes.
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Conservative weekly garbage collection keeps rollback generations without
  # deleting the store immediately after every rebuild.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # SSD maintenance.
  services.fstrim.enable = true;

  # Locale and timezone are shared defaults; a host can override them.
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  # NetworkManager is used by the desktop, laptop, and TUI tools.
  networking.networkmanager.enable = true;

  # Keep the firewall explicitly enabled for the safer shared baseline.
  networking.firewall.enable = true;

  # SSH is explicitly available but requires keys and should not use passwords.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitEmptyPasswords = false;
    };
  };

  # Real-time audio scheduling support.
  security.rtkit.enable = true;

  # PipeWire shared by all desktop/laptop hosts.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Zsh is the shared interactive shell.
  programs.zsh.enable = true;

  # Personal account; host-specific groups are added by hosts where needed.
  users.users.rambeau = {
    isNormalUser = true;
    description = "rambeau";
    shell = pkgs.zsh;
  };

  # Allow proprietary software such as NVIDIA, Steam, and Spotify.
  nixpkgs.config.allowUnfree = true;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  # Fonts shared on all machines.
  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];

  system.stateVersion = "26.05";
}
