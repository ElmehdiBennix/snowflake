# NixOS configuration

This directory is the complete NixOS configuration for both machines.
It is intended to be the only NixOS subtree stowed as `/etc/nixos`.

```text
nixos/
├── flake.nix                 # One flake, two host configurations
├── flake.lock                # Pinned nixpkgs and application flake inputs
├── hosts/
│   ├── desktop/
│   │   ├── default.nix       # AMD Ryzen + NVIDIA RTX 3090 desktop
│   │   └── hardware-configuration.nix
│   └── thinkpad/
│       ├── default.nix       # Intel/AMD ThinkPad host rules
│       └── hardware-configuration.nix  # Placeholder until scanned
└── modules/
    ├── core.nix              # Shared users, locale, networking, Nix, PipeWire
    ├── desktop.nix           # Shared greetd/Niri/GTK/Qt desktop shell
    ├── hardware-amd.nix      # AMD CPU microcode
    └── hardware-nvidia.nix   # NVIDIA/Container Toolkit graphics
```

## Host selection

Build or switch the desktop:

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake .#desktop
```

Build or switch the ThinkPad after replacing its placeholder hardware scan:

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake .#thinkpad
```

## Updating

```bash
cd /etc/nixos
nix flake update
sudo nixos-rebuild build --flake .#desktop
sudo nixos-rebuild switch --flake .#desktop
```

Use the ThinkPad host name on the ThinkPad instead.

## Storage

The desktop mounts two shared NTFS drives in `hosts/desktop/default.nix`:

- `/mnt/external-storage` — 1.8 TB USB SSD (`External Storage`) for the
  shared Steam library
- `/mnt/cold-storage` — 1 TB HDD (`Cold Storage`) for bulk data

They use the in-kernel `ntfs3` driver with `nofail` and automount, so a
missing drive cannot block boot. Formatting, mount options, Windows Fast
Startup, Steam/Proton caveats, and recovery are covered in
`Docs/storage-ntfs-shared.md`.

## Adding a machine

1. Copy `nixos/hosts/thinkpad` or create `nixos/hosts/<name>`.
2. Run `nixos-generate-config --root /mnt` on the target installer or
   `sudo nixos-generate-config --show-hardware-config` on an existing target.
3. Put the result in `hosts/<name>/hardware-configuration.nix`.
4. Add shared modules in `modules/` if the setting is useful on several hosts.
5. Add only host-specific modules in `hosts/<name>/default.nix`.
6. Add `nixosConfigurations.<name>` to `flake.nix`.
7. Build before switching:

```bash
nix build .#nixosConfigurations.<name>.config.system.build.toplevel
```

## Why this layout

- One flake lock pins every machine.
- Shared modules prevent duplicated desktop settings.
- Hardware files contain only machine-specific disks and kernel modules.
- A desktop NVIDIA module cannot accidentally be imported into the ThinkPad.
- Older generations and `nixos-rebuild switch --rollback` remain available.
