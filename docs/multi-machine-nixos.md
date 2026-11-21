# Multi-machine NixOS layout

This repository now keeps one complete, reusable NixOS subtree:

```text
snowflake/nixos/
```

It is meant to be stowed directly as:

```text
/etc/nixos
```

The repository should not also have a `nixos/etc/nixos/` compatibility layout.
The symlink used for the desktop is:

```text
/etc/nixos -> /home/rambeau/snowflake/nixos
```

This is easier to understand than stowing an extra `etc/nixos` inside the
repository, and it keeps machine configuration in one obvious directory.

---

## Directory structure

```text
nixos/
├── flake.nix
├── flake.lock
├── README.md
├── hosts/
│   ├── desktop/
│   └── thinkpad/
├── hardware/
└── modules/
```

### `hosts/`

One directory per physical machine:

- `hosts/desktop/default.nix` — AMD Ryzen + NVIDIA RTX 3090
- `hosts/thinkpad/default.nix` — laptop host, hardware pending

A host file should contain only machine identity and machine-specific choices:

- Host name
- Imports
- Bootloader
- Account groups
- GPU module
- Gaming or laptop power settings
- Host-specific programs/services

It should not duplicate shared Niri, locale, PipeWire, or user settings.

### `modules/`

Reusable cross-machine configuration:

- `core.nix` — locale, users, Nix store, networking, PipeWire, SSH, fonts
- `desktop.nix` — greetd, niri, GTK/Qt, Wayland, desktop packages
- `hardware-amd.nix` — AMD CPU microcode
- `hardware-nvidia.nix` — NVIDIA driver, 32-bit graphics, Docker CDI

A module should answer “what capability should machines that import this get?”

### `hardware/`

Generated hardware scans live near a host or in a dedicated hardware module:

- root Btrfs subvolumes
- EFI partition
- swap devices
- kernel modules
- I/O bus modules
- platform name

Never copy the desktop UUIDs into the ThinkPad. Disk UUIDs are machine-specific.

---

## Desktop host

Build/switch:

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake .#desktop
```

The desktop imports:

```nix
./hardware/desktop.nix
./modules/core.nix
./modules/desktop.nix
./modules/hardware-amd.nix
./modules/hardware-nvidia.nix
```

It is intentionally wrong to import `hardware-nvidia.nix` on a laptop that
does not have the same NVIDIA setup.

---

## ThinkPad host

Build/switch after the hardware scan exists:

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake .#thinkpad
```

The placeholder `hardware-configuration.nix` currently has no root filesystem
definition. That is intentional: it prevents the wrong disk UUID or partition
layout from being copied from the desktop.

On the ThinkPad, generate hardware configuration:

```bash
sudo nixos-generate-config --show-hardware-config
```

Or, from the installer:

```bash
sudo nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix ./hosts/thinkpad/hardware-configuration.nix
```

After replacing the placeholder, add the ThinkPad CPU/GPU modules if needed:

- Intel CPU: `hardware.cpu.intel.updateMicrocode = true`
- AMD CPU: use `modules/hardware-amd.nix`
- Intel iGPU: use Mesa; no NVIDIA module
- NVIDIA laptop GPU: import `hardware-nvidia.nix` and configure Optimus/PRIME if present

---

## Shared and host-specific packages

Core package policy belongs in `modules/core.nix` only if it should be on every
machine.

Desktop-only packages belong in `modules/desktop.nix` or
`hosts/desktop/default.nix`.

Laptop-only packages belong in `hosts/thinkpad/default.nix`.

Examples:

```nix
# Shared
neovim
btop
fastfetch

# Desktop-only
steam
obs-studio
sunshine

# Laptop-only
powertop
brightnessctl
```

This keeps the laptop from receiving RTX 3090, Steam, or desktop-gaming services
it does not need.

---

## Adding a third machine

1. Create `hosts/<machine>/default.nix`.
2. Generate `hosts/<machine>/hardware-configuration.nix`.
3. Import shared `core.nix` and `desktop.nix` if it has a desktop.
4. Import only the CPU/GPU modules that apply.
5. Add `nixosConfigurations.<machine>` to `flake.nix`.
6. Build first:

```bash
nix build .#nixosConfigurations.<machine>.config.system.build.toplevel
```

7. Switch after a successful build:

```bash
sudo nixos-rebuild switch --flake .#<machine>
```

---

## Stow flow

Best-practice stow layout:

```text
/home/rambeau/snowflake/nixos -> /etc/nixos
```

Do not include dotfiles or docs inside `/etc/nixos`. The repository root can
contain `docs/`, `dotfiles/`, and `nixos/`, while only `nixos/` is linked to
`/etc/nixos`.

Example `/etc/nixos` link:

```bash
sudo ln -sfn /home/rambeau/snowflake/nixos /etc/nixos
```

Verify:

```bash
readlink -f /etc/nixos
ls /etc/nixos/flake.nix
```

Expected:

```text
/home/rambeau/snowflake/nixos
```

---

## Updating and rollback

Update all flake inputs:

```bash
cd /etc/nixos
nix flake update
sudo nixos-rebuild switch --flake .#desktop
```

Build without activating:

```bash
sudo nixos-rebuild build --flake /etc/nixos#desktop
```

Rollback:

```bash
sudo nixos-rebuild switch --rollback
```

---

## Safety checklist

- Keep the hardware scan machine-specific.
- Keep GPU modules machine-specific.
- Keep shared account/time/audio/locale modules in `modules/core.nix`.
- Keep the desktop shell in `modules/desktop.nix`.
- Never link the whole Snowflake repository to `/etc/nixos`.
- Build a host before switching it.
- Commit and lock the flake before major updates.
