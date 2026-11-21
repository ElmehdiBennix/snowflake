# NixOS beginner workflow

This guide explains how this particular system is managed. It assumes you are
coming from Arch Linux and are used to `pacman`, `yay`, and editable service
files under `/usr` or `/etc`.

---

## The one NixOS rule

> Permanent configuration belongs in `/etc/nixos`; temporary testing belongs in `nix shell` or `nix run`.

This machine stores its live NixOS files in:

```text
/home/rambeau/snowflake/nixos/etc/nixos
```

That directory is linked into `/etc/nixos`:

```text
/etc/nixos -> /home/rambeau/snowflake/nixos/etc/nixos
```

The repository root flake is not the live system configuration. The live system
is built from:

```text
/etc/nixos/flake.nix
/etc/nixos/flake.lock
/etc/nixos/hardware-configuration.nix
/etc/nixos/configuration.nix
```

When the repository is stowed, only `snowflake/nixos` is linked into `/etc`.
Changes to the repository copy are therefore also changes to the live config
because `/etc/nixos` is a symlink.

---

## Permanent packages

Do not permanently install a package with `pacman`, `yay`, or `paru`. NixOS has
no `paru` equivalent workflow.

Edit:

```bash
sudoedit /etc/nixos/configuration.nix
```

Add the package under `environment.systemPackages`:

```nix
environment.systemPackages = with pkgs; [
  htop
  ripgrep
  bat
];
```

Then build and activate:

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake .#nixos
```

The configuration name is `nixos`, so `.#nixos` means:

```text
flake in current directory
→ nixosConfigurations.nixos
```

Do not edit files under `/run/current-system`; those are generated symlinks.

---

## Install a package temporarily

For testing, use `nix shell`:

```bash
nix shell nixpkgs#htop
htop
```

The shell is temporary. Closing it removes the package from the shell's PATH.

Run a package once:

```bash
nix run nixpkgs#fastfetch
```

Search for a package:

```bash
nix search nixpkgs package-name
```

Examples:

```bash
nix search nixpkgs ffmpeg
nix search nixpkgs obs-studio
nix search nixpkgs speedtest-go
```

For an interactive package environment:

```bash
nix shell nixpkgs#ripgrep nixpkgs#fd nixpkgs#jq
```

Those tools stay temporary unless they are added to
`environment.systemPackages`.

---

## Rebuild without switching

Preview and build a configuration without making it active:

```bash
cd /etc/nixos
sudo nixos-rebuild build --flake .#nixos
```

This is useful before a reboot or before switching to a configuration that
changes the kernel, NVIDIA modules, display manager, or bootloader.

Apply and activate a configuration:

```bash
sudo nixos-rebuild switch --flake .#nixos
```

Test an activation without making it the boot default:

```bash
sudo nixos-rebuild test --flake .#nixos
```

The distinction matters:

| Command | Activates now | Becomes boot default |
|---|---:|---:|
| `build` | No | No |
| `test` | Yes | No |
| `switch` | Yes | Yes |
| `boot` | No | Yes |

For a normal rebuild, use `switch`.

---

## Update package inputs

This system is unstable-first. Flake inputs are recorded in `flake.lock`.
Updating inputs means fetching newer package snapshots; it does not change the
live system until `nixos-rebuild switch` runs.

Update all inputs:

```bash
cd /etc/nixos
nix flake update
sudo nixos-rebuild switch --flake .#nixos
```

Update only nixpkgs:

```bash
cd /etc/nixos
nix flake lock --update-input nixpkgs
sudo nixos-rebuild switch --flake .#nixos
```

Update only one application flake:

```bash
nix flake lock --update-input hermes-agent
nix flake lock --update-input zen-browser
```

Update the stable fallback independently:

```bash
nix flake lock --update-input nixpkgs-stable
```

Safe workflow:

```bash
cd /etc/nixos
nix flake update
sudo nixos-rebuild build --flake .#nixos
sudo nixos-rebuild switch --flake .#nixos
```

Build first. Switch second.

---

## Switch without changing updates

To activate the exact versions in `flake.lock`:

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake .#nixos
```

No `nix flake update` is required.

To rebuild the lock-backed system through an absolute path:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

This is the simplest command to remember:

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake .#nixos
```

---

## Kernel, bootloader, and NVIDIA changes

A reboot is required after changing:

- Linux kernel package
- NVIDIA driver/module configuration
- systemd-boot
- initrd
- CPU microcode
- major display-manager changes
- Docker NVIDIA toolkit configuration

Check the running and booted systems:

```bash
uname -r
readlink -f /run/booted-system
readlink -f /run/current-system
```

If they differ, reboot:

```bash
sudo reboot
```

After a reboot:

```bash
nvidia-smi
lsmod | grep nvidia
```

NVIDIA modules should appear, and `nvidia-smi` should report the RTX 3090.

---

## System generations and rollback

List generations:

```bash
nixos-rebuild list-generations
```

Rollback to the previous activated generation:

```bash
sudo nixos-rebuild switch --rollback
```

At boot time, open the systemd-boot menu and select an older NixOS generation.
This is useful after:

- A kernel change fails
- A NVIDIA driver fails
- A display manager stops working
- A package update breaks the desktop
- A package update breaks Steam or Proton

A rollback is usually safer than editing random files to compensate for a bad
change.

---

## Services

Permanent services are enabled in `configuration.nix`, not by downloading a
package and using `systemctl enable` unless the service is user-created.

Examples:

```nix
services.openssh.enable = true;
services.pipewire.enable = true;
programs.steam.enable = true;
virtualisation.docker.enable = true;
```

Check a service:

```bash
systemctl status sshd
systemctl status docker
systemctl status greetd
systemctl status pipewire
```

For user services:

```bash
systemctl --user status noctalia
systemctl --user list-units
```

View service logs:

```bash
journalctl -u sshd -b
journalctl -u docker -b
journalctl -u greetd -b
journalctl --user -u niri -b
```

Restart a service:

```bash
sudo systemctl restart sshd
sudo systemctl restart docker
systemctl --user restart noctalia
```

---

## Editing configuration safely

Open the main file:

```bash
sudoedit /etc/nixos/configuration.nix
```

Keep the existing comments unless they are wrong or obsolete. The comments in
this configuration explain why the settings exist.

Before switching:

```bash
nix-instantiate --parse /etc/nixos/configuration.nix >/dev/null
sudo nixos-rebuild build --flake /etc/nixos#nixos
```

The parser catches syntax errors. The build catches module and package errors.

Format Nix files:

```bash
nix fmt /etc/nixos
```

The formatter is not always installed by default; install `nixfmt` temporarily
with:

```bash
nix shell nixpkgs#nixfmt
nixfmt /etc/nixos/configuration.nix
```

---

## Installing and updating applications

Permanent application example:

```nix
environment.systemPackages = with pkgs; [
  obs-studio
  foliate
  swayimg
  qpwgraph
];
```

Add it, then:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Temporary application example:

```bash
nix shell nixpkgs#gimp

gimp
```

Do not install a package into the system if it is only needed for one test.

---

## Stable fallback

This flake keeps a stable nixpkgs input named `nixpkgs-stable`.

In `configuration.nix`, the stable alias is:

```nix
stable
```

A stable package can be selected individually:

```nix
environment.systemPackages = with pkgs; [
  bat
  stable.neovim
];
```

This is useful only when a specific package regresses on unstable. It does not
currently build a full stable NixOS system; it is an explicit stable-package
fallback.

---

## Standard desktop workflow

Typical package change:

```bash
sudoedit /etc/nixos/configuration.nix
cd /etc/nixos
sudo nixos-rebuild build --flake .#nixos
sudo nixos-rebuild switch --flake .#nixos
```

Typical update:

```bash
cd /etc/nixos
nix flake update
sudo nixos-rebuild build --flake .#nixos
sudo nixos-rebuild switch --flake .#nixos
```

If kernel or NVIDIA changed:

```bash
sudo reboot
```

If something breaks:

```bash
sudo nixos-rebuild switch --rollback
```

---

## Channel migration

The system may still contain old Nix channels. Channels are separate from
flakes and are only needed for `<nixpkgs>` imports.

List channels:

```bash
nix-channel --list
```

Update channels:

```bash
sudo nix-channel --update
nix-channel --update
```

The preferred workflow is now the flake. Once all imports are gone,
channel configuration can be removed.

Remove a channel:

```bash
sudo nix-channel --remove nixos
sudo nix-channel --remove nixos-unstable
nix-channel --remove nixos
nix-channel --remove nixos-unstable
```

Do not remove channels until the flake build and switch have been verified.

---

## Useful daily commands

```bash
# Edit the live configuration
sudoedit /etc/nixos/configuration.nix

# Update flake inputs
cd /etc/nixos && nix flake update

# Preview
sudo nixos-rebuild build --flake /etc/nixos#nixos

# Apply
sudo nixos-rebuild switch --flake /etc/nixos#nixos

# Roll back
sudo nixos-rebuild switch --rollback

# Search
nix search nixpkgs htop

# Temporary shell
nix shell nixpkgs#gdu nixpkgs#ripgrep

# Run once
nix run nixpkgs#fastfetch

# List generations
nixos-rebuild list-generations

# Verify GPU
nvidia-smi

# Verify Docker GPU
sudo docker run --rm --gpus all nvidia/cuda:12.9.1-base-ubuntu24.04 nvidia-smi

# Verify NVIDIA Docker config
systemctl status nvidia-container-toolkit-cdi-generator
```

---

## The shortest memory aid

Permanent package/config change:

```bash
sudoedit /etc/nixos/configuration.nix
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Update everything:

```bash
cd /etc/nixos
nix flake update
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Temporary package:

```bash
nix shell nixpkgs#package-name
```

Bad rebuild:

```bash
sudo nixos-rebuild switch --rollback
```

Reboot after kernel, NVIDIA, bootloader, or display-manager changes:

```bash
sudo reboot
```
