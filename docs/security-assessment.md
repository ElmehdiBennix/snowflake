# Security assessment — 2026-11-20

## Overall rating

**Current security rating: approximately 5/10.**

The system has a reasonable NixOS/PAM baseline, active kernel mitigations, and
a restrictive Nix trusted-user configuration. However, the network exposure is
too broad because the firewall is disabled while SSH listens on every network
interface. AppArmor is also not enabled, and there is no documented full-disk
encryption or personal-data backup policy.

This is a defense-in-depth assessment for a personal gaming and dual-boot
machine, not a formal security audit.

---

## Current security state

| Area | Current state | Assessment |
|---|---|---|
| Firewall | Disabled | **Critical gap** |
| SSH | Enabled on `0.0.0.0:22` and `[::]:22` | **High exposure** |
| PAM | Basic Unix/PAM stack active | Good baseline |
| AppArmor | Not enabled or loaded | No AppArmor confinement |
| Secure Boot | Disabled | Physical boot-chain protection reduced |
| Kernel mitigations | Active | Good |
| Nix trusted users | Only `root` | Good |
| Docker group | User is a member | Root-equivalent access through Docker |
| `nix-ld` | Enabled | Wider foreign-binary execution surface |
| Insecure packages | Electron exception configured | Should be temporary |
| Backups/snapshots | No clear policy | High data-loss risk |
| Disk encryption | No LUKS root configuration detected | Physical-theft risk |
| Audit logging | Kernel audit collection disabled | Lower visibility during incidents |

---

## PAM

### Rating: 7/10 baseline

PAM is active for Ly and login services. The current stack includes:

```text
pam_unix
pam_systemd
pam_env
pam_loginuid
pam_limits
pam_gnome_keyring
```

The user account has a password and uses the normal Unix PAM authentication
path. The password status was confirmed as set:

```text
rambeau P
```

The PAM stack provides:

- Unix password authentication
- `yescrypt` password hashing
- Systemd user-session integration
- Login accounting IDs
- Resource limits
- GNOME Keyring unlock at login
- A dedicated Ly PAM service

### PAM gaps

There is no configured:

- FIDO2/YubiKey authentication
- Fingerprint authentication
- General brute-force lockout for Ly and SSH
- Two-factor authentication
- Explicit SSH-specific PAM hardening
- Strong password-quality policy visible in this configuration

`pam_faillock` appears in the generated configuration for `su`, but that does
not automatically protect every service, including Ly and SSH.

PAM protects authentication and sessions. It does not sandbox applications or
replace a network firewall.

---

## AppArmor and Linux security modules

### AppArmor rating: 0/10 currently

AppArmor is not active:

```text
apparmor.service: not found
/sys/kernel/security/apparmor: not found
```

The live LSM list is:

```text
capability,landlock,yama,bpf
```

It does not include `apparmor`.

The kernel command line contains:

```text
lsm=landlock,yama,bpf
```

Systemd was built with AppArmor support, but that only means systemd can
interoperate with AppArmor. It does not enable AppArmor profiles.

### Existing protections

#### Landlock

Landlock allows applications to restrict their own filesystem access. It is
useful when an application opts into it, but it is not a system-wide policy
like AppArmor.

#### Yama

Yama provides useful process and `ptrace` restrictions for desktop systems.

#### BPF

BPF supports kernel instrumentation, networking, scheduling, and security
tools. Its presence alone is not an application sandbox.

### AppArmor recommendation

AppArmor can be enabled later with a small, tested profile set. High-value
targets are:

- SSH
- Browsers
- Download tools
- Network-facing daemons
- Docker-related services

Steam, Proton, Wine, Gamescope, and NVIDIA applications should not be
aggressively confined without testing because profiles can break games and
graphics functionality.

---

## Network exposure

The configuration currently contains:

```nix
networking.firewall.enable = false;
```

The live system exposes SSH on all IPv4 and IPv6 interfaces:

```text
0.0.0.0:22
[::]:22
```

Steam and games also create listening sockets. These are not automatically
vulnerabilities, but disabling the firewall gives every service a larger
network exposure than necessary.

### Highest-priority fix

Enable the firewall:

```nix
networking.firewall = {
  enable = true;
  allowedTCPPorts = [ 22 ]; # Keep only if SSH is needed.
};
```

If SSH is not needed, disable it instead:

```nix
services.openssh.enable = false;
```

---

## SSH hardening

If SSH is required, use public-key authentication and configure it explicitly:

```nix
services.openssh = {
  enable = true;
  settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitEmptyPasswords = false;
    AllowUsers = [ "rambeau" ];
    MaxAuthTries = 3;
    X11Forwarding = false;
  };
};
```

Confirm key-based login works before disabling password authentication, or the
machine could become inaccessible remotely.

---

## Privileged groups and execution surface

The user is a member of:

```text
wheel
docker
libvirtd
networkmanager
```

`wheel` is required for administrative `sudo` access. `networkmanager` is
normal for a desktop. `docker` is effectively root-equivalent because Docker
can start privileged containers and mount the host filesystem. `libvirtd`
also grants broad virtualization control.

Keep these groups only when needed. Removing Docker or libvirt access reduces
the impact of a compromised desktop application, but may interfere with the
user's development and gaming workflow.

The configuration also enables:

```nix
programs.nix-ld.enable = true;
```

This is convenient for foreign binaries, launchers, and games, but broadens
the set of unpatched or externally obtained binaries that can run.

---

## Insecure package exception

The configuration currently permits:

```nix
nixpkgs.config.permittedInsecurePackages = [
  "electron-39.8.10"
];
```

Electron embeds Chromium components, so old Electron versions can contain
browser security vulnerabilities. Keep this exception only while its dependent
application requires it, and remove it when the package is updated.

`allowUnfree = true` is a licensing choice and is not itself a security
vulnerability, although third-party proprietary software still needs normal
trust and update caution.

---

## Boot and physical security

Secure Boot is currently disabled:

```text
Secure Boot: disabled
Measured UKI: no
```

This is understandable for an NVIDIA gaming setup with custom kernel/module
requirements. It means the firmware does not cryptographically verify the
bootloader and kernel, so physical access provides a greater opportunity for
boot-chain tampering.

The current system is UEFI-based and uses systemd-boot. Enabling Secure Boot
later would require signing the NixOS boot artifacts and NVIDIA modules and
testing a recovery path first.

No LUKS-encrypted root device was detected in the current hardware
configuration. If the machine or drive is stolen, unencrypted `/home` data
could be read. Full-disk encryption is strongly recommended for a fresh
installation or a carefully planned migration.

---

## Backups and recovery

NixOS generations protect the system closure and configuration rollback, but
they do not provide complete backups of:

- `/home/rambeau`
- Browser profiles
- SSH keys
- Steam save data
- Documents and pictures
- Dotfiles
- Application state

Btrfs snapshots would help with accidental changes, but they are not a
replacement for an external or remote backup. Keep at least one backup that is
not permanently mounted to the machine.

---

## Recommended hardening order

1. Enable the firewall.
2. Disable SSH if it is not needed.
3. If SSH is needed, use keys and disable password authentication.
4. Add brute-force lockout protection to SSH and Ly after checking the exact
   PAM options in the active nixpkgs version.
5. Add external backups and optionally Btrfs snapshots.
6. Remove the insecure Electron exception when possible.
7. Remove `docker` or `libvirtd` group access if no longer needed.
8. Enable AppArmor selectively with tested profiles.
9. Consider LUKS encryption for a future reinstall or migration.
10. Consider Secure Boot after the NVIDIA/NixOS signing process is tested.

The firewall and SSH changes provide the largest immediate security benefit.
AppArmor, FIDO2, audit logging, and Secure Boot are valuable additional
layers, but should follow the network and backup fixes.

---

## Verification commands

```bash
# Network exposure
sudo ss -tulpen
systemctl is-active firewall

# SSH policy
sudo sshd -T | grep -E \
  '^(port|passwordauthentication|kbdinteractiveauthentication|permitrootlogin|allowusers|maxauthtries)'

# PAM/AppArmor
cat /sys/kernel/security/lsm
systemctl status apparmor
aa-status

# Boot security
bootctl status
cat /proc/cmdline

# User privileges
id
getent group docker
getent group libvirtd

# System updates and failed services
systemctl --failed
nixos-rebuild list-generations
```
