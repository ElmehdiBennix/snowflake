# Shared NTFS storage (games + bulk data)

This machine has two NTFS drives shared with Windows:

| Mount | Device | UUID | Purpose |
| --- | --- | --- | --- |
| `/mnt/games` | `/dev/sdb1` | `A810C8EA10C8C114` | 1.8 TB USB SSD, Steam/game storage |
| `/mnt/bulk` | `/dev/sda1` | `78E2938CE2934CEE` | 1 TB HDD, bulk data (`Cold Storage`) |

The mount definitions live in `nixos/hosts/desktop/default.nix`.

## Why `ntfs3` and not `ntfs-3g`

Linux has two NTFS implementations:

- **`ntfs3`** — the in-kernel driver. Fast, read-write, used by these mounts.
- **`ntfs-3g`** — the older FUSE driver. Slower, but it also ships `mkntfs`,
  `ntfsfix`, `ntfslabel`, and `ntfsresize`.

`nixos/modules/core.nix` enables:

```nix
boot.supportedFilesystems = [ "ntfs" ];
```

On the current kernel this makes NixOS use `ntfs3g` as the mount helper and
loads the kernel driver. `ntfs3g` is also installed in
`nixos/modules/desktop.nix` so GParted can see the NTFS format option.

## Formatting a drive with GParted

GParted hides NTFS unless `mkntfs` is on its `PATH`. After a rebuild with
`ntfs3g` installed:

1. **Close and reopen GParted** (a running instance keeps the old `PATH`).
2. Select the disk, then **Device → Create Partition Table → GPT**.
3. Right-click the unallocated space → **New**.
4. Set file system to **ntfs**, give it a label, use the full size.
5. Click the green checkmark → **Apply**.

Formatting erases the whole disk. Confirm the device and size first.

## Finding UUIDs

```bash
lsblk -f
# or
sudo blkid /dev/sdX1
```

Always mount by UUID, not `/dev/sdX`, because device letters change.

## Declarative mount

The pattern used for both drives:

```nix
fileSystems."/mnt/games" = {
  device = "/dev/disk/by-uuid/A810C8EA10C8C114";
  fsType = "ntfs3";
  options = [
    "uid=1000"
    "gid=100"
    "umask=022"
    "iocharset=utf8"
    "nofail"
    "x-systemd.automount"
    "x-systemd.device-timeout=10s"
  ];
};
```

What the options do:

| Option | Meaning |
| --- | --- |
| `uid=1000` `gid=100` | Files belong to `rambeau:users` instead of root. |
| `umask=022` | Directories/files get normal `755` permissions, with exec bits. |
| `iocharset=utf8` | Correct Unicode filenames. |
| `nofail` | Boot continues if the drive is unplugged. |
| `x-systemd.automount` | Mount on first access instead of blocking boot. |
| `x-systemd.device-timeout=10s` | Fail fast if the device is missing. |

After a switch, access the directory once to trigger the mount:

```bash
ls /mnt/games
findmnt /mnt/games
```

## udiskie vs declarative mounts

udiskie is still useful for random USB sticks and SD cards. It mounts them
under `/run/media/rambeau/<label>`.

For permanent drives, declarative mounts are better because:

- the path never changes (Steam stores library paths)
- they work without a graphical session
- mount options are fixed and reproducible

udisks2/udiskie ignore drives already mounted by `/etc/fstab`, so the two
systems do not fight.

## Windows side

Disable Fast Startup and hibernation, or Windows leaves the NTFS volume
"dirty" and Linux may mount it read-only or refuse to mount:

```powershell
powercfg /h off
```

Also uncheck **Control Panel → Power Options → Choose what the power buttons
do → Turn on fast startup**.

## Steam and Proton on the NTFS SSD

Steam on Linux does not officially support NTFS libraries. With `ntfs3` it
often works, but keep these points in mind:

1. Add the library on Linux: **Steam → Settings → Storage → Add Drive**, then
   pick `/mnt/games/Games/Steam`.
2. **Proton prefixes are the usual breakage.** Keep `compatdata` on Btrfs and
   symlink it into the NTFS library:

   ```bash
   rm -rf /mnt/games/Games/Steam/steamapps/compatdata
   ln -s ~/.local/share/Steam/steamapps/compatdata \
         /mnt/games/Games/Steam/steamapps/compatdata
   ```

   Adjust the path if your library folder has a different name.
3. Native Linux games are safer on the internal Btrfs disk.
4. Anti-cheat games still will not run on Linux, regardless of filesystem.

## Growing the HDD filesystem to the full partition

After formatting, check that the filesystem fills the partition:

```bash
df -h /mnt/bulk
sudo ntfsresize --info --force /dev/sda1
```

If `Current volume size` is smaller than `Current device size`, growing is
non-destructive and keeps the data, but back up anything important first:

```bash
sudo umount /mnt/bulk
sudo ntfsresize /dev/sda1
ls /mnt/bulk                                # remount via automount
```

Never shrink an NTFS filesystem while it is mounted.

> **Note:** reformatting a drive in Windows (or anywhere else) generates a new
> UUID and label. If a mount starts failing after booting Windows, run
> `lsblk -f` and update the UUID in `hosts/desktop/default.nix`.

## Troubleshooting

### NTFS mounts read-only or says the volume is dirty

Boot Windows and shut it down properly with Fast Startup disabled. As a last
resort from Linux:

```bash
sudo umount /mnt/bulk
sudo ntfsfix /dev/sda1
```

### Permission denied

Check the mount options include `uid=1000,gid=100,umask=022`:

```bash
findmnt -no OPTIONS /mnt/bulk
```

### Automount does not trigger

```bash
systemctl status mnt-games.automount mnt-bulk.automount
ls /mnt/games
findmnt /mnt/games
```

### `nixos-rebuild switch` fails with "Unit ...mount is masked"

An interrupted switch can leave runtime masks on the boot/Nix mounts, which
also makes `/nix/store` read-only and stops `nix-daemon`. Recover with:

```bash
sudo systemctl unmask --runtime nix.mount nix-store.mount boot.mount home.mount
sudo mount -o remount,rw /nix/store
sudo systemctl restart nix-daemon.socket
```

Then retry the switch.

### Unplug safely

```bash
udisksctl unmount -b /dev/sdb1
# or
sudo umount /mnt/games
```

## Safety notes

- Keep backups of the bulk data.
- Before formatting, verify the device with `lsblk -f` and `df -h`.
- Reformatting changes the NTFS UUID; update the mount if it stops working.
- Prefer `nofail` and automount for removable drives so a missing disk cannot
  block boot.
