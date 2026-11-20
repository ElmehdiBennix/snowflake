# PLACEHOLDER — generated hardware configuration for the ThinkPad.
# Run on the ThinkPad:
#   sudo nixos-generate-config --show-hardware-config
#
# Replace this file with the generated boot.initrd, fileSystems, swapDevices,
# kernel modules, and nixpkgs.hostPlatform for that laptop.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  swapDevices = [ ];
}
