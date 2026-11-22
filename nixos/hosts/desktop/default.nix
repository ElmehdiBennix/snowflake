# Desktop host: AMD Ryzen + NVIDIA RTX 3090.
{ config, pkgs, zen-browser, spicetify-nix, ... }:

let
  zen-browser-pkg = zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
  spicePkgs = spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core.nix
    ../../modules/desktop.nix
    ../../modules/desktop-services.nix
    ../../modules/hardware-amd.nix
    ../../modules/hardware-nvidia.nix
  ];

  networking.hostName = "nixos-desktop";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Shared NTFS storage, mounted with the in-kernel ntfs3 driver.
  # nofail keeps boot working if a drive is unplugged; automount mounts on
  # first access instead of blocking the boot.
  fileSystems."/mnt/external-storage" = {
    device = "/dev/disk/by-uuid/A810C8EA10C8C114";
    fsType = "ntfs3";
    options = [
      "uid=1000"
      "gid=100"
      "umask=022"
      "iocharset=utf8"
      "nofail"
      "x-systemd.automount"
      "x-systemd.device-timeout=10s"
    ];
  };

  fileSystems."/mnt/cold-storage" = {
    device = "/dev/disk/by-uuid/78E2938CE2934CEE";
    fsType = "ntfs3";
    options = [
      "uid=1000"
      "gid=100"
      "umask=022"
      "iocharset=utf8"
      "nofail"
      "x-systemd.automount"
      "x-systemd.device-timeout=10s"
    ];
  };

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

  # CachyOS-style responsiveness: auto-nice background work with the CachyOS
  # ruleset, and load the gaming-oriented sched_ext scheduler at boot.
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  systemd.services.scx-lavd = {
    description = "scx_lavd sched_ext CPU scheduler";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.scx.rustscheds}/bin/scx_lavd";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Power-profile switching for Noctalia and desktop power modes.
  services.tuned = {
    enable = true;
    ppdSupport = true;
  };

  # DDC/CI monitor brightness and settings via ddcutil.
  hardware.i2c.enable = true;

  users.users.rambeau.extraGroups = [
    "networkmanager"
    "wheel"
    "docker"
    "libvirtd"
    "i2c"
  ];

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
    zen-browser-pkg
  ];

  # Spotify is installed by the spicetify-nix module as a patched package.
  # Do not add pkgs.spotify or spicetify-cli to systemPackages.
  # Themes and extensions are applied at build time: the patched Spotify lives
  # read-only in the Nix store, so there is no in-app installer. To add more,
  # pick names from `spicePkgs.extensions` / `spicePkgs.themes` and rebuild.
  programs.spicetify = {
    enable = true;

    enabledExtensions = with spicePkgs.extensions; [
      adblockify
      hidePodcasts
      keyboardShortcut
      shuffle
    ];
  };

  programs.gamemode.settings = {
    general.renice = 10;
    cpu = {
      desiredgov = "performance";
      defaultgov = "powersave";
    };
  };

  # Hermes Agent: native service backed by the local llama-swap endpoint.
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    settings = {
      model = {
        default = "llama/llama-swap";
        base_url = "http://127.0.0.1:9292/v1";
      };
      toolsets = [ "all" ];
    };

    backend = {
      mode = "dashboard";
      host = "127.0.0.1";
      port = 9119;
    };

    hermesHomeFiles = {
      "SOUL.md" = "You are a helpful local AI operator. Prefer local tools and never expose credentials.";
    };
  };

  # Realtek ALC1200A reports the front headphone jack as plugged, and the default
  # "Auto-Mute Mode" then disables the rear green Line Out pin, silencing the
  # speakers. Keep both outputs active.
  systemd.services.alsa-disable-automute = {
    description = "Disable HDA auto-mute so the rear Line Out stays active";
    wantedBy = [ "sound.target" ];
    after = [ "sound.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.alsa-utils}/bin/amixer -c Generic sset 'Auto-Mute Mode' Disabled";
    };
  };
}
