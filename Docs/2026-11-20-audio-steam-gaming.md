# Session log — 2026-11-20

Work done on the NixOS gaming machine: audio fix, config cleanup, Steam/Proton
tooling, Xwayland under niri, and CachyOS-style performance tuning.

- **Host:** `nixos` (ASUS TUF GAMING B550M-PLUS WIFI II, BIOS 3636)
- **CPU:** AMD Ryzen 9 5900X (12C/24T, Zen 3)
- **GPU:** NVIDIA RTX 3090 (GA102)
- **Audio codec:** Realtek ALC1200A (`1043:8797`)
- **Compositor:** niri 26.04 + ly + PipeWire/WirePlumber
- **Config:** `/home/rambeau/snowflake/nixos/etc/nixos/configuration.nix`
  (symlinked from `/etc/nixos`)

---

## 1. Audio — speakers and front headphones at the same time

### Symptom

Rear speakers went silent as soon as headphones were plugged into the front
jack. Only one output could be active at a time.

### Root cause

The ALC1200A reports **both** jacks as plugged:

```
Front Headphone Jack : plugged
Line Out Front Jack : plugged
```

With `Auto-Mute Mode = Enabled`, HDA auto-mute disables the rear Line Out pin
whenever the front headphone jack is occupied:

```
Pin-ctls: 0x00   # rear pin 0x14 disabled
```

Disabling auto-mute restored the rear pin (`Pin-ctls: 0x40: OUT`) and both
outputs worked simultaneously.

### Fix (declarative)

`configuration.nix`, Audio section:

```nix
systemd.services.alsa-disable-automute = {
  description = "Disable HDA auto-mute so the rear Line Out stays active";
  wantedBy = [ "sound.target" ];
  after = [ "sound.target" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    ExecStart = "${pkgs.alsa-utils}/bin/amixer -c Generic sset 'Auto-Mute Mode' Disabled";
  };
};
```

### Default sink / route

PipeWire sink `alsa_output.pci-0000_09_00.4.analog-stereo` was set to the
`analog-output-lineout` port at 70% volume. The choice is saved by WirePlumber
in:

```
~/.local/state/wireplumber/default-routes
```

It survives WirePlumber restarts. No extra config is needed for it.

### Verify

```bash
systemctl status alsa-disable-automute
amixer -c Generic sget 'Auto-Mute Mode'    # should be [Disabled]
pactl list sinks | grep -A2 'Active Port'  # analog-output-lineout
```

---

## 2. `configuration.nix` reorganisation

The file was reorganised into labelled sections without changing behaviour:

```
Boot & kernel            systemd-boot, sysctl, zram, ananicy, gamemode, scx
Nix / store / filesystem nix.settings, gc, fstrim
Hardware & graphics      NVIDIA, hardware.graphics, bluetooth, fonts
Networking, locale, kbd  hostname, NetworkManager, firewall, timezone, i18n, xkb
Users
Packages                 unfree, insecure packages, systemPackages
Desktop & session        zsh, ly, niri, virtualisation
Gaming                   steam, Proton-GE, ProtonPlus, ProtonTricks
Audio (PipeWire)         pipewire + auto-mute fix
Power management         upower, tuned, conflicting daemons off
System services          ssh, nix-ld, xdg-user-dirs
```

Cleanups (no behaviour change):

- Fixed unindented `hardware.nvidia` block and tab-indented
  `permittedInsecurePackages`.
- Packages sorted alphabetically inside their existing comment groups.
- Removed the duplicate `zathura` entry.
- `users.users."rambeau"` → `users.users.rambeau`.
- Trailing whitespace removed, `nixfmt` applied.

**Comment policy:** every original comment is preserved. This was verified
against the pre-rewrite backup with:

```bash
comm -23 \
  <(grep -E '^[[:space:]]*#' backup.nix | sed -E 's/^[[:space:]]*//' | sort -u) \
  <(grep -E '^[[:space:]]*#' configuration.nix | sed -E 's/^[[:space:]]*//' | sort -u)
```

Only *new* section dividers and explanatory notes were added.

---

## 3. Steam, ProtonPlus, ProtonTricks

`configuration.nix`:

```nix
# Gaming
programs.steam.enable = true;
programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];

environment.systemPackages = with pkgs; [
  # Gaming
  gamescope
  goverlay
  mangohud
  protonplus
  protontricks
];
```

What each one does:

| Package | Purpose |
|---|---|
| `programs.steam.enable` | Steam + 32-bit runtime, `steam-run`, controller/VR udev rules |
| `proton-ge-bin` | Proton-GE installed as a Steam compatibility tool |
| `protonplus` | GUI to install/update Proton-GE and other compatibility tools |
| `protontricks` | winetricks-style tweaks inside a game's Proton prefix |
| `mangohud` | FPS / frametime / GPU overlay |
| `goverlay` | GUI to configure MangoHud |
| `gamescope` | Micro-compositor: frame limiting, FSR, resolution scaling |

`hardware.graphics.enable32Bit = true` was already set and is required by
Steam.

Usage:

```bash
protontricks -l            # list games/prefixes
protontricks --gui
protontricks <appid> vcrun2022
```

Steam → `Settings → Compatibility` → enable Steam Play for all titles, then
pick **GE-Proton** per game under `Properties → Compatibility`.

### ProtonPlus launch options (gamescope, MangoHud, …)

**Symptom:** in ProtonPlus you add launch options such as `gamescope -W 2560
-H 1440 -f -- %command%`, click apply, and it says Steam must restart. After
restarting Steam the options are gone. ProtonPlus's own restart button can also
hang with an error.

**Cause:** ProtonPlus writes to Steam's config while Steam is still running.
When Steam exits it rewrites `localconfig.vdf` from memory and wipes the change.
ProtonPlus's restart helper then fails on NixOS, and a stale
`~/.steam/steam.pid` / `~/.steam/steam.pipe` left by an unclean shutdown makes
the next launch hang.

**Working procedure:**

1. Fully close Steam: `Steam → Exit`, or from a terminal:
   ```bash
   steam -shutdown
   ```
   Wait until no Steam process is left:
   ```bash
   pgrep -af '[s]team/steam' || echo 'steam closed'
   ```
2. Only if Steam is closed and the next launch hangs, remove the stale locks:
   ```bash
   rm -f ~/.steam/steam.pid ~/.steam/steam.pipe
   ```
   Never delete these while Steam is running.
3. Open ProtonPlus and apply the launch options for the game.
4. **Ignore / cancel ProtonPlus's restart prompt.** Do not let it restart Steam.
5. Start Steam yourself:
   ```bash
   steam &
   ```
6. Verify the option was written. Steam games store it in `localconfig.vdf`:
   ```bash
   grep -n 'LaunchOptions' \
     ~/.local/share/Steam/userdata/*/config/localconfig.vdf
   ```
   Non-Steam shortcuts (added via `Games → Add a Non-Steam Game`) store it in
   the binary `shortcuts.vdf`:
   ```bash
   grep -a -o 'LaunchOptions.\{0,80\}' \
     ~/.local/share/Steam/userdata/*/config/shortcuts.vdf
   ```
   You should see your `gamescope … %command%` string after `LaunchOptions`.
7. Launch the game. A `gamescope` window/compositor starting means the option
   took effect.

If the option is still missing after step 6, close Steam again and repeat — the
config was overwritten because Steam was not fully closed at step 3.

### “Steam changes need attention” — ProtonPlus refuses to apply

**Symptom:** ProtonPlus shows:

> Steam changes need attention
> Steam is closed. ProtonPlus could not safely apply every pending change;
> retry or start Steam manually after resolving the conflict.

**Cause:** ProtonPlus keeps a receipt of every change it made while Steam was
running in:

```text
~/.local/state/ProtonPlus/steam-restart-state.json
```

Each receipt records the target shortcut/app id and a fingerprint of the file
at the time of the change. If Steam later rewrites `shortcuts.vdf` or
`config.vdf`, or if the shortcut was removed and re-added (a new app id), the
fingerprint no longer matches. ProtonPlus then refuses to overwrite the file
rather than risk clobbering changes it did not make. On this machine the
receipt referenced shortcut `3334041239` while the live ELDEN RING shortcut is
`3602485341`, so it could never reconcile.

**Fix** (Steam and ProtonPlus both closed):

```bash
# 1. Close Steam and ProtonPlus first.
pkill -x protonplus; steam -shutdown

# 2. Back up the receipt and the Steam config files.
ts=$(date +%Y%m%d-%H%M%S)
cp -a ~/.local/state/ProtonPlus/steam-restart-state.json \
      ~/.local/state/ProtonPlus/steam-restart-state.json.bak-$ts
cp -a ~/.local/share/Steam/userdata/*/config/shortcuts.vdf \
      ~/.local/share/Steam/userdata/*/config/shortcuts.vdf.bak-$ts
cp -a ~/.local/share/Steam/config/config.vdf \
      ~/.local/share/Steam/config/config.vdf.bak-$ts

# 3. Clear the stale pending-change receipts.
jq '{schema_version: .schema_version, records: []}' \
  ~/.local/state/ProtonPlus/steam-restart-state.json > /tmp/pp.json
chmod 600 /tmp/pp.json
mv /tmp/pp.json ~/.local/state/ProtonPlus/steam-restart-state.json
```

Then reopen ProtonPlus, apply the launch options with Steam still closed, ignore
the restart prompt, and start Steam yourself (steps 1–7 above).

To check the receipt without editing it:

```bash
jq -r '.records[] | [.kind, .subject_id,
        .configuration_intent.path, .configuration_intent.desired]
       | @tsv' ~/.local/state/ProtonPlus/steam-restart-state.json
```

Compare `subject_id` with the app id in `shortcuts.vdf`. For a non-Steam
shortcut, the first 4 bytes after the `appid` key are a little-endian `int32`:

```bash
od -An -tu4 -j 21 -N 4 \
  ~/.local/share/Steam/userdata/*/config/shortcuts.vdf
```

---

## 4. Xwayland — Steam would not start under niri

### Symptom

```
Unable to open X11 display, exiting
```

The GTK/zenity crash in the log (`Unrecognized image file format`) was only
Steam's error dialog failing to render — a symptom, not the cause.

### Diagnosis

```
DISPLAY=<unset>
xwayland processes: none
/tmp/.X11-unix: empty
```

Steam is an X11 client and the niri session had no Xwayland at all.

### Fix

niri ≥ 25.08 has **built-in xwayland-satellite integration**: if
`xwayland-satellite >= 0.7` is in `$PATH` when niri starts, niri creates the
X11 socket and exports `$DISPLAY` itself.

So only the package is needed:

```nix
# Desktop, Audio & Wayland Tools
xwayland-satellite # X11 apps (Steam, etc.) under niri
```

**Do not** add `spawn-at-startup "xwayland-satellite"`. Manual spawning
conflicts with niri's own instance (the niri wiki explicitly says to remove
it). The temporary line added to
`dotfiles/niri/.config/niri/cfg/autostart.kdl` was reverted.

### Important

`$DISPLAY` and the session `PATH` are set at login. After the rebuild you must
**log out of niri and log back in** — a `switch` alone does not update the
running session.

### Verify

```bash
echo $DISPLAY                                # :0
journalctl --user-unit=niri -b | grep 'X11 socket'
# niri[...]: listening on X11 socket: :0
```

Manual test used during debugging (not needed normally):

```bash
export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1
xwayland-satellite &
xrandr --display :0 --query                  # 3440x1440
```

---

## 5. Gaming performance — CachyOS parity

### The blocker that mattered most

The machine was still running **generation 1**:

```
booted system : ...-nixos-system-nixos-26.05.13627...  (kernel 6.18.60)
/run/current-system : ...-nixos-system-nixos-26.05.14753... (kernel 6.18.64)
```

`nixos-rebuild switch` had activated a newer generation, but the kernel cannot
change without a reboot. Gen 1 predates the NVIDIA configuration, so the RTX
3090 was driven by **nouveau**:

```
nouveau 0000:07:00.0: NVIDIA GA102
modinfo: ERROR: Module nvidia not found
nvidia-smi: failed to communicate with the driver
```

No amount of sysctl/scheduler tuning compensates for that. A reboot is
mandatory.

### Applied tuning

| Item | Before | After |
|---|---|---|
| GPU driver | nouveau (gen 1) | nvidia 595.71.05 after reboot |
| CPU microcode | not loaded | `hardware.cpu.amd.updateMicrocode = true` (amd-ucode 20261019) |
| NVIDIA KMS | modeset only | `boot.extraModprobeConfig = "options nvidia_drm modeset=1 fbdev=1"` |
| `vm.swappiness` | 10 (disk-swap value) | 100 — correct for zram |
| GameMode | no governor switch | `powersave` idle → `performance` while active, `renice=10` |
| CPU scheduler | stock EEVDF | `scx_lavd` (sched_ext) |
| Steam compat | Steam Proton only | Proton-GE via `extraCompatPackages` |
| Overlay/tools | none | `mangohud`, `goverlay`, `gamescope` |
| Wayland vars | none | `GBM_BACKEND=nvidia-drm`, `__GLX_VENDOR_LIBRARY_NAME=nvidia` |

Already present and kept: zram (zstd, 50%), ananicy-cpp with CachyOS rules,
`vm.max_map_count=2147483642`, `vm.vfs_cache_pressure=50`, CAKE + BBR,
GameMode.

Relevant snippets:

```nix
hardware.cpu.amd.updateMicrocode = true;
boot.extraModprobeConfig = "options nvidia_drm modeset=1 fbdev=1";

boot.kernel.sysctl = {
  "vm.vfs_cache_pressure" = 50;
  "vm.swappiness" = 100;              # zram: compressed RAM swap is cheap
  "vm.max_map_count" = 2147483642;
  "net.core.default_qdisc" = "cake";
  "net.ipv4.tcp_congestion_control" = "bbr";
};

programs.gamemode.settings = {
  general.renice = 10;
  cpu = {
    desiredgov = "performance";
    defaultgov = "powersave";
  };
};

systemd.services.scx-lavd = {
  description = "scx_lavd sched_ext CPU scheduler";
  wantedBy = [ "multi-user.target" ];
  after = [ "systemd-modules-load.service" ];
  serviceConfig = {
    Type = "simple";
    ExecStart = "${pkgs.scx.rustscheds}/bin/scx_lavd";
    Restart = "on-failure";
    RestartSec = 2;
  };
};
```

### Zen kernel — attempted, not usable yet

`linuxPackages_zen` (7.3.5) fails to build against NVIDIA 595.71.05:

```
nvidia/os-interface.c:732: error: implicit declaration of function 'strncpy'
```

Linux 7.3 removed `strncpy`; the newest NVIDIA driver in nixpkgs still uses
it. Every alternative kernel in this nixpkgs (zen, xanmod, lqx) is also 7.3.5,
and 7.0–7.2 were dropped as EOL. The line therefore stays commented in
`configuration.nix`, with a note explaining why. Keep 6.18 until a newer
NVIDIA driver lands.

---

## 6. Post-reboot checklist

```bash
uname -r                          # 6.18.64
lsmod | grep nvidia               # nvidia, nvidia_drm, nvidia_modeset, nvidia_uvm
nvidia-smi                        # RTX 3090, 595.71.05, 24576 MiB
echo $DISPLAY                     # :0
systemctl status scx-lavd         # active (running)
cat /sys/kernel/sched_ext/state   # enabled
systemctl status alsa-disable-automute
pactl list sinks | grep -A2 'Active Port'
```

Then launch Steam. Per-game launch options:

```bash
gamemoderun mangohud %command%                            # governor + overlay
gamemoderun gamescope -W 3440 -H 1440 -f -- %command%     # gamescope (optional)
```

---

## 7. Rollback / troubleshooting

```bash
# If scx_lavd misbehaves in a game
sudo systemctl stop scx-lavd
sudo /nix/store/yfyczx090z3rbycimjzkaaz0vgg33f2z-scx_rustscheds-1.1.4/bin/scx_bpfland
sudo systemctl disable --now scx-lavd     # permanent

# If the audio auto-mute service does not apply at boot
sudo systemctl restart alsa-disable-automute

# If Xwayland is missing after login
#   - confirm xwayland-satellite is on PATH, then log out/in again
#   - do NOT spawn it manually alongside niri

# Roll back a generation
sudo nixos-rebuild switch --rollback
```

Old generations are kept, so a bad kernel/driver boot can be recovered from the
systemd-boot menu.

---

## 8. Open items

- Run `sudo nixos-rebuild switch` to activate build
  `j9ss6qgcn55w0n6dnda588kx6pzlshpn`, then reboot and verify NVIDIA is
  actually loaded (the only unverified step).
- Re-check the Zen kernel once nixpkgs ships an NVIDIA driver that supports
  Linux 7.3.
- Optional: `programs.steam.gamescopeSession.enable = true;` for a console-like
  session in `ly` (line is present but commented in the Gaming section).
