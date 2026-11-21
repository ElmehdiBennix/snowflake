# Shared desktop-session settings for Niri-capable workstations.
{ config, pkgs, ... }:

{
  # greetd/Tuigreet replaces a heavyweight desktop display manager.
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --xsessions ${config.services.displayManager.sessionData.desktops}/share/xsessions --session-wrapper '${config.services.displayManager.sessionData.wrapper}'";
        user = "greeter";
      };
    };
  };

  # Niri session and Wayland integration.
  programs.niri.enable = true;

  # Bluetooth support for bluetui and desktop Bluetooth controls.
  hardware.bluetooth.enable = true;

  # Qt platform integration.
  qt.enable = true;
  qt.platformTheme = "qt5ct";

  # GTK/Qt/Noctalia session values.
  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    GTK_THEME = "adw-gtk3-dark";
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };

  # Desktop and Wayland packages.
  environment.systemPackages = with pkgs; [
    # Terminal CLI tools
    bat
    btop
    eza
    fastfetch
    fzf
    gdu
    gh
    git
    gnumake
    jq
    neovim
    rclone
    speedtest-go
    stow
    tldr
    tmux
    tesseract
    yazi
    zoxide

    # DevOps / virtualization CLI
    docker-compose
    gh-dash
    lazygit
    lazydocker
    sops
    age
    packer
    vagrant

    # Desktop, audio, and Wayland
    bibata-cursors
    colloid-icon-theme
    gnome-themes-extra
    noto-fonts-color-emoji
    papirus-icon-theme
    adw-gtk3
    libsForQt5.qt5ct
    kdePackages.qt6ct

    awww
    bluetui
    ddcutil
    easyeffects
    ghostty
    llama-cpp-vulkan
    llama-swap
    noctalia
    nwg-look
    qpwgraph
    udiskie
    wiremix
    wl-clipboard
    xwayland-satellite

    # Media, documents, and notes
    foliate
    logseq
    swayimg
    mpv
    zathura

    # GUI applications
    gparted
    keepassxc
    nautilus
    onlyoffice-desktopeditors
    obs-studio
    stremio-linux-shell
    vesktop
    xdg-user-dirs
    zed-editor

    # Gaming overlays, compatibility, and Proton prefix tools.
    gamescope # micro-compositor: frame limiting, FSR, resolution scaling
    goverlay # GUI to configure MangoHud
    mangohud # on-screen FPS / frametime / GPU overlay
    sunshine # remote game/desktop streaming host
    protonplus # manage Proton-GE / compatibility tools
    protontricks # winetricks-style tweaks inside a game's Proton prefix
  ];

  # UDisks2 is required by udiskie and removable-disk desktop integration.
  services.udisks2.enable = true;

  # Create standard Desktop, Downloads, Documents, Pictures, and related
  # directories for the graphical session.
  systemd.user.services.xdg-user-dirs = {
    description = "Update XDG user directories";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.xdg-user-dirs}/bin/xdg-user-dirs-update";
    };
  };
}
