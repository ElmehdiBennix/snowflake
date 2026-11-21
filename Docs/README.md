# Snowflake docs

Notes and session logs for this NixOS configuration.

- [2026-11-20 — Audio, Steam, Xwayland and gaming tuning](2026-11-20-audio-steam-gaming.md)
  — simultaneous speakers + front headphones, config reorganisation,
  Steam/Proton tooling, Xwayland under niri, CachyOS-style performance tuning.
- [Dual-boot assessment](dual-boot-assessment.md)
  — systemd-boot, Windows EFI entry, disk layout, rollback safety, and
  recommended dual-boot precautions.
- [Security assessment](security-assessment.md)
  — PAM, AppArmor, LSMs, firewall, SSH, privileged groups, boot security,
  backups, and the prioritized hardening plan.
- [Unstable, stable fallback, Docker NVIDIA, llama-swap and Hermes](unstable-stable-llama-docker.md)
  — stowed flake layout, unstable/stable package policy, NVIDIA container GPU
  passthrough, local llama-swap, secret handling, and Hermes deployment.
- [NixOS beginner workflow](nixos-beginner-workflow.md)
  — permanent and temporary packages, updating flakes, rebuilding, rollback,
  kernel/NVIDIA reboots, channels, services, and a safe daily workflow.
- [Multi-machine NixOS layout](multi-machine-nixos.md)
  — desktop/ThinkPad host separation, shared modules, hardware scans,
  `/etc/nixos` stow flow, and adding another machine.
- [Shared NTFS storage](storage-ntfs-shared.md)
  — declarative mounts for the game SSD and bulk HDD, GParted NTFS formatting,
  `ntfs3` mount options, Windows Fast Startup, Steam/Proton caveats, growing
  the filesystem, and recovery steps.
