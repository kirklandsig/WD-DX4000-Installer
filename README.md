# WD-DX4000-Installer
## A solderless Debian installer for the WD DX4000. No case removal, soldering or serial ports required!

Work In Progress

# Please use the prebuilt ISOs under [Releases](https://github.com/kirklandsig/WD-DX4000-Installer/releases) if you don't know what you're doing. If you do know what you're doing and want to use the scripts to assemble your own images, please test the prebuilt ISOs before reporting issues, and include the results.

---

## Troubleshooting
### Kernel modules error message
![image](https://github.com/alexhorner/WD-DX4000-Installer/assets/33007665/ce344fb8-ad4c-4d92-ab6b-72848cb2dab4)

If you encounter this error page, please open an issue. This is caused by Debian removing kernel modules from their archive repository, and requires a refreshed ISO file to be built and released by myself.

### Pings but won't SSH
If you encounter this problem, please open an issue. I haven't checked what causes this, but I have found it is similar to the Kernel modules error message, and requires a refreshed ISO file to be built and released by myself.

---

Credit goes to @1000001101000 for https://github.com/1000001101000/Debian_on_Intel_Terastations/

---
## Preface

The released version is a prerelease, however it should be suitable for production use. The difference between this prerelease and the intended final product will be automation of certain tasks which usually require manual work, namely:
- LCDProc for LCD control
- Fancontrol
- Automated startup script placement (explained below)

The final installer will also have some useful features like displaying the IP address on the network on the LCD during the installer and showing the current installer status too.

The repository currently includes installer templates for `Buster`, `Bullseye`, `Bookworm`, and `Trixie`. If you want the newest template in this repository, use `Trixie/`.

---

## Building An ISO
These scripts are intended to be run from Linux as `root`, as they use `mount`, `cpio`, and `xorriso` to rebuild Debian's netboot `mini.iso`.

Build dependencies:

```bash
sudo apt-get update
sudo apt-get install -y bash coreutils cpio gzip mount wget xorriso
```

The build downloads Debian's `mini.iso` and its `SHA256SUMS` file, then verifies the ISO checksum before rebuilding the installer image.

When run from WSL against a repository checked out under `/mnt/c`, the build automatically stages its temporary files inside the Linux filesystem and only writes the final ISO and credentials file back to `output/`.

To build the newest template in this repository:

```bash
cd Trixie
sudo ./generate_images.sh
```

The output image will be written to `Trixie/output/dx4000-trixie-installer.iso`.

By default, each build now generates a unique SSH secret for the installer and writes it to `output/dx4000-<distro>-installer.credentials.txt`.

If you want to control that yourself, you can override it at build time:

```bash
cd Trixie
sudo DX4000_INSTALLER_PASSWORD='replace-this' ./generate_images.sh
```

You can also expose an SSH public key URL for the Debian network-console installer:

```bash
cd Trixie
sudo DX4000_AUTHORIZED_KEYS_URL='https://example.com/authorized_keys' ./generate_images.sh
```

If you want the lower-risk Debian base for a Plex deployment on old hardware, build `Bookworm/` instead of `Trixie/`.

This fork publishes known-good installer builds through [GitHub Releases](https://github.com/kirklandsig/WD-DX4000-Installer/releases) instead of tracking large ISO artifacts in git. The matching installer credentials file can also be published, but this fork leaves it out by default because the installer secret is temporary and publishing it is usually unnecessary.

---

## Installation
To use the latest prerelease, you will want to write (balena Etcher, Win32DiskImager, DD etc) the ISO image to a USB drive and insert it into any of the ports on the back of your DX4000.

Avoid using Rufus to write the image unless you know what you're doing (you need to write raw instead of letting Rufus install a bootloader). Using Rufus without disabling its "assistive" bootloader features will cause incorrect parameters to be specified to boot the installer, resulting in the installer USB not working, or even more likely, it working but the emergency serial console being disabled both on the installer and in the final Debian installation, since the final installation appears to be affected by the installer's boot parameters.

With the DX4000 powered down but plugged in, hold the reset button on the back (for example with a pen. Avoid metal objects) and press the power button. Continue to hold the button until the LCD shows the Loading Recovery message.

The LCD will stay on Loading Recovery for the remainder of the installation as there is no software in the installer to drive the LCD at this time.

Use your router's IP lease page or a tool like Advanced IP Scanner or NMAP to scan your network for the DX4000. It should automatically retrieve an IP address when it has fully started.

Connect via SSH to the IP address of the DX4000 using the SSH CLI or a tool like PuTTY or your OS's native SSH client. If you do not get a connection immediately, it could take up to 15 minutes for the SSH server to start.

When asked for the details to log in, the username is `installer`.

If you are using an upstream prebuilt ISO, the password may still be `dx4000`.

If you built the ISO yourself with the current scripts in this repository, use the installer secret written to `output/dx4000-<distro>-installer.credentials.txt` as the SSH password.

NOTE: Make sure to enable SSH Server and basic system utilities when prompted to select software. You should probably disable the graphical desktop environment too, as the DX4000 has not video output and will just waste resources. You may wish to install a graphical environment and use VNC, XRDP or X2Go later.

---

## Post Installation
Current builds in this repository attempt to automate the DX4000 boot fix during Debian's installer `late_command` by copying `startup.nsh` onto the installed system's EFI System Partition before the installer exits.

If the system still fails to boot after install, use the manual fallback:

1. Press and hold the reset button again to boot the installer and log back in.
2. Go to the bottom of the action list and choose Start shell.
3. Run `disk-detect` to ensure all disk device nodes have been populated.
4. Ensure the FAT kernel module is loaded with `modprobe vfat` otherwise mount attempts can fail with `Invalid Argument`.
5. Mount your installation's boot partition (usually the first partition on the installed disk) and copy `startup.nsh` from the installer environment to the root of that boot partition.
6. Reboot and the system should come online on its own.

---

## Plex Bootstrap
Once Debian is installed and booting normally, the repository includes a helper script to install Plex Media Server from Plex's official apt repository:

```bash
sudo ./scripts/bootstrap_plex.sh
```

After Plex is installed, open `http://<dx4000-ip>:32400/web` and complete the initial setup.

---

## SMB / Samba Bootstrap
For a Windows-friendly media workflow, the repository also includes a helper script to install and configure Samba with a simple authenticated media share:

```bash
sudo ./scripts/bootstrap_samba.sh --user <linux-user>
```

By default, the script creates:

- `/srv/media/movies`
- `/srv/media/tv`
- `/srv/media/music`
- `/srv/media/homevideos`
- `/srv/downloads`

The default Windows share path will be:

```text
\\<dx4000-ip>\media
```

Plex can then be pointed at the same `/srv/media/*` folders.

---

## CasaOS
If you want a friendlier web management UI on top of Debian, the repository also includes a helper to install CasaOS:

```bash
sudo ./scripts/bootstrap_casaos.sh
```

CasaOS is optional. It layers on top of Debian and can coexist with manually configured services like Plex and Samba.

After install, open:

```text
http://<dx4000-ip>/
```

If you later decide not to keep CasaOS, remove it with:

```bash
sudo casaos-uninstall
```

---

Notes:

- If you have existing data on your DX4000, please take a backup. I am not liable for any data loss you endure as a result of using this software.
- If you had a stock Windows installation RAID, it should be possible to retain this as MDADM should detect it an use it, as MDADM appears to support Intel Rapid RAID.
- You will need to follow the old guide (the soldered install one, but don't worry, no soldering needed!) for the Fan and LCD setup. Find it at https://github.com/alexhorner/WD-DX4000 .
- If you have soldered wires to your DX4000 and want to use the serial console for the install instead of SSH, this has been enabled for you. Soldering to access the serial port is COMPLETELY OPTIONAL for this installer, as this installer is intended to work without even opening your DX4000's cover.
