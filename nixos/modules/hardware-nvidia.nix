# NVIDIA desktop/laptop hardware module.
# Import this only on machines that have an NVIDIA GPU and proprietary drivers.
{ config, pkgs, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
    nvidiaSettings = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  boot.extraModprobeConfig = "options nvidia_drm modeset=1 fbdev=1";

  # Docker/Podman-style container GPU passthrough.
  hardware.nvidia-container-toolkit.enable = true;
}
