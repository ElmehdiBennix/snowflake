# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- CachyOS-style Performance Tweaks ---
  # 1. Use the low-latency Zen kernel (similar responsiveness to CachyOS)
  # (Commented out if binary cache misses; uncomment only if prebuilt cache is ready)
  # boot.kernelPackages = pkgs.linuxPackages_zen;

  # 2. Sysctl optimizations for desktop responsiveness & networking
  boot.kernel.sysctl = {
    # Keep directory and inode caches in memory longer
    "vm.vfs_cache_pressure" = 50;
    # Avoid swapping to disk until absolutely necessary
    "vm.swappiness" = 10;
    # Needed for high-performance gaming / Wine / Proton
    "vm.max_map_count" = 2147483642;

    # Network optimizations (CachyOS default):
    # CAKE queue management fights bufferbloat (lag under load)
    "net.core.default_qdisc" = "cake";
    # Google BBR congestion control maximizes throughput and minimizes latency
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # 3. ZRAM (Compressed RAM swap like CachyOS/Fedora)
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # 4. Ananicy-cpp: process auto-nice daemon for prioritizing foreground apps
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos; # Uses official CachyOS priority rules!
  };

  # 5. Feral GameMode for on-demand performance boosting
  programs.gamemode.enable = true;
  # ----------------------------------------

  # --- Nix Package Manager & Store Maintenance (QoL) ---
  nix.settings = {
    # Enable modern 'nix' commands and Flakes support
    experimental-features = [ "nix-command" "flakes" ];

    # Automatically hardlink identical files in /nix/store to save SSD space
    auto-optimise-store = true;
  };

  # Automatically clear out old generations once a week (like pacman -Scc)
  # Prevents /nix/store from filling up your drive over time
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Run periodic SSD TRIM to maintain drive health and write speeds
  services.fstrim.enable = true;

  # Enable 3D hardware acceleration & 32-bit support (vital for games/Wine/Steam)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  # -----------------------------------------------------

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties.
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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."rambeau" = {
    isNormalUser = true;
    description = "rambeau";
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" ];
    shell = pkgs.zsh;
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages =
    let
      unstable = import <nixos-unstable> {
        config = config.nixpkgs.config;
      };
      zen-browser = (builtins.getFlake "github:0xc000022070/zen-browser-flake").packages.${pkgs.system};
    in
    with pkgs; [
      # Terminal CLI tools
      fastfetch
      btop
      tmux
      stow
      eza
      zoxide
      bat
      neovim
      fzf
      jq
      yazi
      tldr
      git
      gh
      gnumake
      unstable.opencode
      udiskie
      
      nautilus
      

      xdg-user-dirs
      
      # DevOps & Virtualization CLI
      gh-dash
      lazydocker
      lazygit
      docker-compose
      vagrant
      packer
      sops
      age

      # Desktop, Audio & Wayland Tools
      ghostty
      zathura
      noctalia
      unstable.vicinae
      unstable.nirimon
      awww

      logseq
      mpv
      zathura
      
      bluetui
      wiremix
      easyeffects

      # GUI Applications
      zed-editor
      keepassxc
      vesktop
      stremio-linux-shell
      moonlight-qt
      
      zen-browser.default
    ];

  # System Fonts
  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];


  systemd.user.services.xdg-user-dirs = {
    description = "Update XDG user directories";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update";
    };
  };

  
  # Shell configuration
  programs.zsh.enable = true;

  # Display Manager (Ly TUI Login Screen)
  services.displayManager.ly.enable = true;

  # Wayland Compositor (Niri)
  programs.niri.enable = true;

  # Virtualization & Containers
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # Audio (PipeWire)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # enable upower 
  services.upower.enable = true;

  # Ensure conflicting daemons are off
  services.power-profiles-daemon.enable = false;
  services.tlp.enable = false;

  services.tuned = {
    enable = true;
    ppdSupport = true; # On by default, explicitly shown for clarity

    # Optional: customize how Noctalia's 3 modes map to TuneD profiles
    # ppdSettings = {
    #   main.default = "balanced";
    #   profiles = {
    #     power-saver = "powersave";
    #     balanced = "balanced";
    #     performance = "throughput-performance";
    #   };
    # };
  };

  
  # Bluetooth (for bluetui)
  hardware.bluetooth.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Enable nix-ld to run unpatched dynamic binaries
  programs.nix-ld = {
    enable = true;
    # Provide common C/C++ libraries that foreign binaries expect
    libraries = with pkgs; [
      stdenv.cc.cc.lib # libstdc++
      zlib             # compression
      openssl          # crypto
      glib             # GNOME/GTK utility library
    ];
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  system.stateVersion = "26.05";
}
