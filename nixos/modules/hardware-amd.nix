# AMD desktop/laptop hardware module.
# This is CPU microcode only: GPU-specific modules belong elsewhere.
{ config, pkgs, ... }:

{
  hardware.cpu.amd.updateMicrocode = true;
}
