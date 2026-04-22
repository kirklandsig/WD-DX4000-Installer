# DX4000 Handoff Memory

Last updated: 2026-04-22

## Current State

- WD DX4000 is installed and booting into Debian Bookworm.
- The DX4000-specific EFI workaround was required after install.
- `startup.nsh` was manually copied to the installed EFI partition from the recovery installer shell.
- System is reachable on the LAN at `10.0.25.251`.

## Storage Layout

- Root filesystem is on `/dev/md126p2`.
- EFI system partition is on `/dev/md126p1`.
- The RAID volume is assembled as `md126` from the four Intel RAID member disks.

## Access

- Primary admin username: `sentinel`
- SSH to the installed box: `sentinel@10.0.25.251`
- Direct root SSH password login was not accepted during setup.
- Admin escalation was performed with `su` on the host.
- Credentials are intentionally not stored in this repo file.

## Services Configured

### Plex

- Plex Media Server is installed from Plex's official apt repository.
- Plex URL: `http://10.0.25.251:32400/web`
- Plex service was verified active after install.
- Plex has not been fully run through the first-time library setup yet.

### Samba / SMB

- Samba is installed and configured.
- SMB share path for Windows: `\\10.0.25.251\media`
- Share name: `media`
- Samba share is authenticated, not guest.
- Samba services were verified active after install.

Media directories created:

- `/srv/media/movies`
- `/srv/media/tv`
- `/srv/media/music`
- `/srv/media/homevideos`
- `/srv/downloads`

Permissions model:

- Group `media` was created.
- `sentinel` and `plex` are members of `media`.
- Media directories are owned by `sentinel:media`.

## CasaOS

- CasaOS was installed on top of the working Debian system.
- Installed version observed during verification: `v0.4.15`
- CasaOS URL: `http://10.0.25.251/`
- CasaOS services were verified active after install.
- Plex and Samba were still active after CasaOS install.

## Rollback / Recovery Notes

- Pre-CasaOS backup path on the box:
  `/root/codex-backups/pre-casaos-20260422-150908`
- CasaOS was added as an overlay on the existing Debian/Plex/Samba setup, not as a replacement OS.
- If CasaOS needs to be removed, use the official uninstall path on the host:
  `casaos-uninstall`

## Practical User Workflow

- Non-technical user path is:
  1. Open `\\10.0.25.251\media` from Windows.
  2. Copy media into the appropriate folders.
  3. Use Plex to browse/play once libraries are configured.

## Open Items

- Plex initial setup and library creation still need to be completed.
- CasaOS should be evaluated for whether it is actually useful for this user as a management UI.
- If Windows discovery is unreliable, continue using the direct UNC path instead of relying on Network browsing.
