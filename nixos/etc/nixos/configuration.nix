# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, stable, hermes-agent, zen-browser, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # ---------------------------------------------------------------------
  # Boot & kernel
  # ---------------------------------------------------------------------
  # Use the systemd-boot EFI boot loader.
  # systemd-boot is the UEFI bootloader for this Windows/NixOS dual-boot setup.
  boot.loader.systemd-boot.enable = true;
  # Allow NixOS to add, remove, and select EFI boot entries for future generations.
  boot.loader.efi.canTouchEfiVariables = true;

  # --- CachyOS-style Performance Tweaks ---
  # 1. Use the low-latency Zen kernel (similar responsiveness to CachyOS)
  # (Commented out if binary cache misses; uncomment only if prebuilt cache is ready)
  # NOTE: Linux 7.3 + NVIDIA 595.71.05 does not compile yet (strncpy removed);
  # keep 6.18 until a newer NVIDIA driver lands in nixpkgs.
  # boot.kernelPackages = pkgs.linuxPackages_zen;

  # AMD microcode updates (Zen 3 fixes, loaded from initrd)
  hardware.cpu.amd.updateMicrocode = true;

  # NVIDIA DRM modesetting + framebuffer console for a clean Wayland handover
  boot.extraModprobeConfig = "options nvidia_drm modeset=1 fbdev=1";

  # 2. Sysctl optimizations for desktop responsiveness & networking
  boot.kernel.sysctl = {
    # Keep directory and inode caches in memory longer
    "vm.vfs_cache_pressure" = 50;
    # Avoid swapping to disk until absolutely necessary
    # (zram makes swapping to compressed RAM cheap, so 100 is the tuned value)
    "vm.swappiness" = 100;
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
    # Enable compressed RAM-backed swap for a 31 GiB desktop/gaming system.
    enable = true;
    # zstd provides a good compression ratio and low CPU cost.
    algorithm = "zstd";
    # Reserve up to half of RAM for the compressed swap pool.
    memoryPercent = 50;
  };

  # 4. Ananicy-cpp: process auto-nice daemon for prioritizing foreground apps
  services.ananicy = {
    # Prioritize games and foreground workloads and de-prioritize background noise.
    enable = true;
    package = pkgs.ananicy-cpp;
    # Import process priorities based on the established CachyOS ruleset.
    rulesProvider = pkgs.ananicy-rules-cachyos; # Uses official CachyOS priority rules!
  };

  # 5. Feral GameMode for on-demand performance boosting
  # Start/performance-tune games through the `gamemoderun` launch wrapper.
  programs.gamemode.enable = true;
  programs.gamemode.settings = {
    general = {
      # Give the game a slightly higher CPU priority while it runs
      renice = 10;
    };
    cpu = {
      # Switch to the performance governor only while GameMode is active
      desiredgov = "performance";
      defaultgov = "powersave";
    };
  };

  # 6. sched_ext: CachyOS-style pluggable CPU scheduler (scx_lavd)
  # Falls back to the stock EEVDF scheduler automatically if it fails to load.
  systemd.services.scx-lavd = {
    # Load a gaming-oriented sched_ext scheduler at boot for lower latency.
    description = "scx_lavd sched_ext CPU scheduler";
    # Start in normal multi-user operation after kernel modules are loaded.
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.scx.rustscheds}/bin/scx_lavd";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
  # ----------------------------------------

  # ---------------------------------------------------------------------
  # Nix, store maintenance & filesystem
  # ---------------------------------------------------------------------
  # --- Nix Package Manager & Store Maintenance (QoL) ---
  nix.settings = {
    # Enable modern `nix` subcommands and reproducible flake support.
    experimental-features = [ "nix-command" "flakes" ];

    # Automatically hardlink identical files in /nix/store to save SSD space
    auto-optimise-store = true;
  };

  # Automatically clear out old generations once a week (like pacman -Scc)
  # Prevents /nix/store from filling up your drive over time
  nix.gc = {
    # Avoid indefinitely retaining old closures after successful rebuilds.
    automatic = true;
    dates = "weekly";
    # Keep one week of rollback data and delete older unreachable generations.
    options = "--delete-older-than 7d";
  };

  # Run periodic SSD TRIM to maintain drive health and write speeds
  services.fstrim.enable = true;
  # -----------------------------------------------------

  # ---------------------------------------------------------------------
  # Hardware & graphics
  # ---------------------------------------------------------------------
  # NVIDIA GPU configuration
  # Use NVIDIA's proprietary closed kernel modules instead of Nouveau for the RTX 3090.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Enable DRM/KMS handoff so Wayland and Xwayland use the NVIDIA display stack.
    modesetting.enable = true;
    # Do not add suspend/resume GPU power-management overrides at this stage.
    powerManagement.enable = false;
    # Use the proprietary (not open) NVIDIA kernel modules for compatibility.
    open = false;
    # Install nvidia-settings for manual GPU and display configuration.
    nvidiaSettings = true;
  };

  # Enable 3D hardware acceleration & 32-bit support (vital for games/Wine/Steam)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Bluetooth (for bluetui)
  # Provide Bluetooth hardware support for bluetui and desktop Bluetooth controls.
  hardware.bluetooth.enable = true;

  # GTK/Qt desktop themes (Noctalia generates GTK/Qt palette files in ~/.config)
  # Install Qt support so Qt applications can use the desktop theme configuration.
  qt.enable = true;
  # Use qt5ct at the module layer; Qt 6 applications receive qt6ct via sessionVariables.
  qt.platformTheme = "qt5ct";

  # DDC/CI monitor brightness and settings via ddcutil.
  # Load i2c-dev and grant the i2c group access to monitor DDC/CI controls.
  hardware.i2c.enable = true;

  # System Fonts
  fonts.packages = with pkgs; [
    # Programming/terminal font without icons.
    jetbrains-mono
    # Nerd-patched JetBrains Mono for terminal prompts and status icons.
    nerd-fonts.jetbrains-mono
  ];

  # ---------------------------------------------------------------------
  # Networking, locale & keyboard
  # ---------------------------------------------------------------------
  # Static local hostname used by networking and graphical-session logs.
  networking.hostName = "nixos";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  # Enable NetworkManager for graphical Wi-Fi/Ethernet configuration and roaming.
  networking.networkmanager.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # Firewall intentionally not enabled yet; should be hardened before exposing SSH.
  networking.firewall.enable = false;

  # Set your time zone.
  # Set the physical/time-display zone for dual-boot and desktop consistency.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties.
  # Base language/format locale, while retaining separate French regional formats below.
  i18n.defaultLocale = "en_US.UTF-8";

  # Keep address, measurement, currency, naming, and time formats French.
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
  # Configure the keyboard layout for X11-compatible clients and login/session tools.
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # ---------------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------------
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.rambeau = {
    # Create an unprivileged interactive account instead of using root for the desktop.
    isNormalUser = true;
    description = "rambeau";
    # NetworkManager, sudo, Docker, libvirt, and DDC/I2C monitor access.
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" "i2c" ];
    # Zsh is the login shell, as selected in this machine's account database.
    shell = pkgs.zsh;
    # Per-user packages are managed through dotfiles/environment rather than this list.
    packages = with pkgs; [ ];
  };

  # ---------------------------------------------------------------------
  # Packages
  # ---------------------------------------------------------------------
  # Allow unfree packages
  # Allow proprietary desktop, NVIDIA, Steam, and Spotify-style packages.
  nixpkgs.config.allowUnfree = true;

  # Explicit exceptions for packages that require an acknowledged insecure release.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages =
    let
      # Default package source: flake nixpkgs unstable. Stable 26.05 is available as
      # `stable` below, for pinning an individual package that regresses on unstable.
      unstable = pkgs;
      # Resolve Zen Browser from the locked external flake input instead of an unlocked getFlake.
      zen-browser-pkg = zen-browser.packages.${pkgs.system}.default;
    in
    with pkgs; [
          # Terminal CLI tools
      # Modern file viewing, process inspection, navigation, and shell utilities.
      bat
      btop
      eza
      fastfetch
      fzf
      gdu
      gh
      llama-cpp-vulkan # llama.cpp llama-server with Vulkan acceleration
      llama-swap # OpenAI-compatible proxy with automatic model swapping
      git
      gnumake
      jq
      neovim
      stow
      tldr
      speedtest-go # internet speed test client
      rclone # cloud storage sync and mount utility
      tmux
      tesseract # OCR engine for extracting text from images
      yazi
      zoxide
      unstable.opencode

      # DevOps & Virtualization CLI
      # Secrets, containers, Git/TUI tools, and VMs.
      age
      docker-compose
      gh-dash
      lazydocker
      lazygit
      packer
      sops
      vagrant

      # Desktop, Audio & Wayland Tools
      # Desktop, audio, Wayland, clipboard, theme, and monitor-management tools.
      awww
      bluetui
      ddcutil # DDC/CI monitor brightness and settings
      easyeffects
      qpwgraph # PipeWire/JACK/PulseAudio connection graph
      ghostty
      adw-gtk3 # GTK3/4 theme package used by Noctalia dynamic wallpaper templates
      bibata-cursors
      colloid-icon-theme
      gnome-themes-extra
      libsForQt5.qt5ct
      kdePackages.qt6ct
      noto-fonts-color-emoji
      noctalia
      nwg-look # GTK appearance editor
      papirus-icon-theme
      udiskie # removable-disk automounting for the Wayland session
      wiremix
      wl-clipboard # wl-copy / wl-paste for Wayland clipboard access
      xwayland-satellite # X11 apps (Steam, etc.) under niri
      unstable.nirimon
      unstable.nirius # named Niri scratchpads / special workspaces
      unstable.vicinae

      # Media, documents & notes
      # Media, document, and note-taking applications.
      foliate # EPUB/e-book reader
      logseq
      mpv
      swayimg # Wayland image viewer
      zathura

      # GUI Applications
      # Disk management, office, recording, games, and communication.
      gparted
      onlyoffice-desktopeditors
      obs-studio
      unstable.hydralauncher # Hydra game launcher
      keepassxc
      nautilus
      unstable.spotify # Spotify desktop client
      unstable.spicetify-cli # Spotify customization CLI
      stremio-linux-shell
      vesktop
      xdg-user-dirs
      zed-editor
      zen-browser-pkg

      # Gaming
      # Gaming overlays, compatibility, and Proton prefix tools.
      gamescope # micro-compositor: frame limiting, FSR, resolution scaling
      goverlay # GUI to configure MangoHud
      mangohud # on-screen FPS / frametime / GPU overlay
      sunshine # remote game/desktop streaming host
      protonplus # manage Proton-GE / compatibility tools
      protontricks # winetricks-style tweaks inside a game's Proton prefix
    ];

  # ---------------------------------------------------------------------
  # Desktop & session
  # ---------------------------------------------------------------------
  # Shell configuration
  # Make Zsh available system-wide and as the configured login shell.
  programs.zsh.enable = true;

  # ---------------------------------------------------------------------
  # Login manager (greetd + tuigreet)
  # ---------------------------------------------------------------------
  # greetd replaces Ly as the system display-manager service.
  services.greetd = {
    enable = true;
    useTextGreeter = true;

    settings = {
      default_session = {
        # Tuigreet presents the tty1 login, remembers the user/session,
        # and discovers Wayland/X11 session desktop entries automatically.
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --xsessions ${config.services.displayManager.sessionData.desktops}/share/xsessions --session-wrapper '${config.services.displayManager.sessionData.wrapper}'";
        user = "greeter";
      };
    };
  };

  # Wayland Compositor (Niri)
  # Enable Niri and its system session/desktop integration.
  programs.niri.enable = true;

  # NVIDIA variables for Wayland / Xwayland clients (GLX + GBM)
  environment.sessionVariables = {
    # Prefer NVIDIA's GBM backend for Wayland-native clients.
    GBM_BACKEND = "nvidia-drm";
    # Force GLX/EGL applications to select the NVIDIA vendor library.
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # GTK/Qt theme integration for Noctalia-generated palettes.
    GTK_THEME = "adw-gtk3-dark";
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };

  # Virtualization & Containers
  # Run Docker workloads and expose the NVIDIA runtime to containers.
  virtualisation.docker.enable = true;
  # Configure NVIDIA Container Toolkit/CDI for Docker GPU passthrough.
  hardware.nvidia-container-toolkit.enable = true;
  # Run QEMU/libvirt virtualization for Virt-Manager and other VMs.
  virtualisation.libvirtd.enable = true;
  # Install the Virt-Manager GUI as the primary libvirt client.
  programs.virt-manager.enable = true;

  # ---------------------------------------------------------------------
  # Hermes Agent (native system service + local llama-swap)
  # ---------------------------------------------------------------------
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

  # ---------------------------------------------------------------------
  # Gaming
  # ---------------------------------------------------------------------
  # Steam (32-bit graphics are already enabled in "Hardware & graphics").
  programs.steam.enable = true;
  # Add a Gamescope session entry to Steam/ly for a console-like launch mode.
  programs.steam.gamescopeSession.enable = true;
  
  # Ship Proton-GE alongside Steam's own Proton builds.
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];

  # ---------------------------------------------------------------------
  # Audio (PipeWire)
  # ---------------------------------------------------------------------
  # Permit real-time scheduling for low-latency audio services when supported.
  security.rtkit.enable = true;

  services.pipewire = {
    # Primary modern Linux audio server for desktop, ALSA, and PulseAudio clients.
    enable = true;
    # Expose ALSA-compatible devices and 32-bit game/audio applications.
    alsa.enable = true;
    alsa.support32Bit = true;
    # Provide the PulseAudio socket/API for Steam and existing desktop apps.
    pulse.enable = true;
  };

  # Realtek ALC1200A on this board reports the front headphone jack as plugged,
  # and the default "Auto-Mute Mode" then disables the rear green Line Out pin,
  # which silences the speakers. Keep both outputs active.
  systemd.services.alsa-disable-automute = {
    description = "Disable HDA auto-mute so the rear Line Out stays active";
    # Run during normal sound startup and retain the setting until another reboot.
    wantedBy = [ "sound.target" ];
    after = [ "sound.target" ];
    serviceConfig = {
      # Use a one-shot exit status because the command only configures the codec once.
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.alsa-utils}/bin/amixer -c Generic sset 'Auto-Mute Mode' Disabled";
    };
  };

  # ---------------------------------------------------------------------
  # Power management
  # ---------------------------------------------------------------------
  # Track battery, AC, and suspend/resume status for Noctalia and desktop controls.
  services.upower.enable = true;

  # Ensure conflicting power-management daemons are off.
  services.power-profiles-daemon.enable = false;
  services.tlp.enable = false;

  services.tuned = {
    # Provide power-profile switching for Noctalia and desktop power modes.
    enable = true;
    # Allow the power-profiles-daemon compatibility interface to be used by the desktop.
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

  # ---------------------------------------------------------------------
  # System services
  # ---------------------------------------------------------------------
  # List services that you want to enable:

  # Enable the OpenSSH daemon for terminal/remote administration; harden later.
  services.openssh.enable = true;

  # Enable nix-ld to run unpatched dynamic binaries
  programs.nix-ld = {
    enable = true;
    # Provide common C/C++ libraries that foreign binaries expect
    libraries = with pkgs; [
      stdenv.cc.cc.lib # libstdc++
      zlib # compression
      openssl # crypto
      glib # GNOME/GTK utility library
    ];
  };

  systemd.user.services.xdg-user-dirs = {
    # Create standard Desktop, Downloads, Documents, Pictures, and related directories.
    description = "Update XDG user directories";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update";
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  system.stateVersion = "26.05";
}
