# Dual-boot assessment — 2026-11-20

## Rating

**Overall: 8/10 for dual boot.**

The system has a sound UEFI dual-boot layout, systemd-boot is installed
correctly, Windows remains present in the EFI configuration, and NixOS keeps
multiple rollback generations. The main gaps are the lack of an explicit boot
menu timeout, no Btrfs snapshot policy, and Secure Boot being disabled.

---

## Current boot state

```text
Firmware mode       UEFI
Bootloader          systemd-boot 260.5
Current entry       nixos-generation-5.conf
Current kernel      6.18.64
Secure Boot         disabled
NVIDIA driver       595.71.05
GPU                 NVIDIA GeForce RTX 3090
```

The machine is now booted into the newer NixOS generation rather than the old
generation that used `nouveau`. The proprietary NVIDIA modules are loaded:

```text
nvidia
nvidia_drm
nvidia_modeset
nvidia_uvm
```

`nvidia-smi` correctly reports the RTX 3090.

---

## Disk layout

The Windows and NixOS installations share the same NVMe drive:

| Partition | Size | Filesystem | Purpose |
|---|---:|---|---|
| `nvme0n1p1` | 6 GB | FAT32 | Shared EFI System Partition, mounted at `/boot` |
| `nvme0n1p2` | 16 MB | — | Microsoft Reserved Partition |
| `nvme0n1p3` | 220 GB | NTFS | Windows partition |
| `nvme0n1p4` | 900 MB | NTFS | Windows Recovery Environment |
| `nvme0n1p5` | 250 GB | Btrfs | NixOS `/`, `/home`, and `/nix` |

The EFI partition has approximately 5.9 GB free, so it has ample space for
Windows boot files and multiple NixOS generations.

NixOS mounts the Btrfs partition using these subvolumes:

```nix
fileSystems."/" = {
  device = "/dev/disk/by-uuid/0df9fff2-8863-4d51-bf1b-9fa6200688c6";
  fsType = "btrfs";
};

fileSystems."/nix" = {
  device = "/dev/disk/by-uuid/0df9fff2-8863-4d51-bf1b-9fa6200688c6";
  fsType = "btrfs";
  options = [ "subvol=nix" ];
};

fileSystems."/home" = {
  device = "/dev/disk/by-uuid/0df9fff2-8863-4d51-bf1b-9fa6200688c6";
  fsType = "btrfs";
  options = [ "subvol=home" ];
};
```

The EFI partition is configured as:

```nix
fileSystems."/boot" = {
  device = "/dev/disk/by-uuid/3CBD-39F9";
  fsType = "vfat";
  options = [ "fmask=0077" "dmask=0077" ];
};
```

---

## Bootloader configuration

The active configuration uses systemd-boot:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
```

The firmware currently contains both boot entries:

```text
Linux Boot Manager  → systemd-boot
Windows Boot Manager → EFI/Microsoft/Boot/bootmgfw.efi
```

This is the preferred arrangement: both operating systems retain their own
EFI bootloader and the firmware can select either one.

Verify the entries with:

```bash
sudo bootctl status
sudo bootctl list
sudo efibootmgr -v
```

The systemd-boot menu should contain the current NixOS generation, older NixOS
generations, and a Windows entry. If Windows is missing from the systemd-boot
menu, it can still be selected through the firmware boot menu using the
Windows Boot Manager entry.

---

## Rollback safety

Several NixOS generations are retained:

```text
system-1  NixOS 26.05.13627, kernel 6.18.60
system-2  NixOS 26.05.14753, kernel 6.18.64
system-3  NixOS 26.05.14753, kernel 6.18.64
system-4  NixOS 26.05.14753, kernel 6.18.64
system-5  NixOS 26.05.14753, kernel 6.18.64
```

If a future NVIDIA, kernel, or desktop update fails, select an older NixOS
generation from systemd-boot or roll back from a working system:

```bash
sudo nixos-rebuild switch --rollback
```

Nix generations protect the operating-system closure, but they do **not** make
complete backups of `/home`. Game saves, documents, dotfiles, and application
state still need a separate backup or Btrfs snapshot policy.

---

## Recommended improvement: show the boot menu

The configuration currently does not explicitly set a boot menu timeout. Add a
short timeout so Windows and older NixOS generations are easy to choose:

```nix
# Show a boot menu so Windows and older NixOS generations are easy to select.
boot.loader.timeout = 5;
```

Then apply it:

```bash
sudo nixos-rebuild switch
```

Five seconds is long enough to make a deliberate selection without making
normal boots feel slow.

---

## Windows compatibility precautions

Disable Windows Fast Startup before accessing Windows NTFS files from NixOS:

```text
Windows Control Panel
→ Power Options
→ Choose what the power buttons do
→ Change settings currently unavailable
→ Disable Fast Startup
```

Do not write to the Windows NTFS partition from NixOS while Windows is
hibernated or Fast Startup is enabled. Windows may leave the filesystem marked
as active, and Linux could corrupt it by mounting it read-write.

Windows updates can also rewrite or reorder EFI boot entries. If a Windows
update changes the default boot entry, use the firmware boot menu to select
Linux Boot Manager again; do not delete the Windows EFI files.

---

## Security notes

Secure Boot is currently disabled:

```text
Secure Boot: disabled
```

This is reasonable for the current gaming setup because the system uses NVIDIA
modules and may use custom kernels or schedulers. It does mean the boot chain
does not cryptographically verify the kernel and bootloader.

Enabling Secure Boot later would require signing the NixOS boot artifacts and
NVIDIA modules, then enrolling the signing key. It is not required for dual
boot to function and should not be enabled without a tested recovery path.

---

## Verification checklist

Run these after bootloader changes or major Windows updates:

```bash
test -d /sys/firmware/efi && echo "UEFI mode: OK"
sudo bootctl status
sudo bootctl list
sudo efibootmgr -v
findmnt /boot
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
```

Expected results:

- UEFI mode is active.
- systemd-boot is the active Linux bootloader.
- Windows Boot Manager still exists.
- `/boot` is mounted from the FAT32 EFI partition.
- The Windows NTFS and recovery partitions are still present.

---

## Final assessment

The dual-boot foundation is solid and suitable for daily use. The most useful
next steps are:

1. Add `boot.loader.timeout = 5`.
2. Verify Windows with `sudo bootctl list` after every bootloader update.
3. Disable Windows Fast Startup.
4. Add Btrfs snapshots or an external backup strategy for `/home`.
5. Keep at least one known-good NixOS generation before major updates.
