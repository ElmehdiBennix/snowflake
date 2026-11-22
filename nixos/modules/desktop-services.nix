# Desktop-only services and applications for device/file integration.
{ pkgs, ... }:
{
  # Nautilus/GVFS: Trash, Network, SMB/SFTP, MTP phones, and mount support.
  services.gvfs = {
    enable = true;
    package = pkgs.gvfs.override { gnomeSupport = true; };
  };
  services.udisks2.enable = true;
  programs.dconf.enable = true;
  security.polkit.enable = true;

  # Discover NAS/Windows/Linux services on the local network.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  # LAN discovery for KDE Connect.
  networking.firewall.allowedTCPPortRanges = [
    { from = 1714; to = 1764; }
  ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 1714; to = 1764; }
  ];

  # File synchronization and remote networking.
  services.tailscale.enable = true;
  services.syncthing = {
    enable = true;
    user = "rambeau";
    group = "users";
    dataDir = "/home/rambeau/.local/share/syncthing";
    configDir = "/home/rambeau/.config/syncthing";
  };

  environment.systemPackages = with pkgs; [
    android-tools
    bottles
    ffmpegthumbnailer
    file-roller
    kdePackages.kdeconnect-kde
    nautilus
    p7zip
    scrcpy
    sshfs
    sushi
    syncthing
    tailscale
    unrar
    unzip
    zip
  ];
}
