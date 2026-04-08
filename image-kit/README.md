# VIDLOOP Master Image Kit

This kit helps you produce a Raspberry Pi master image for VIDLOOP using pi_video_looper.

## Included scripts

- `preclone-cleanup.sh`: run on the MASTER Pi before cloning.
- `install-firstboot-service.sh`: installs a one-shot first boot service.
- `firstboot-init.sh`: one-shot init executed on first boot in clones.
- `build-master-image.sh`: creates `.img.xz` from SD card on Linux host.
- `systemd/vidloop-firstboot.service`: systemd unit for first boot initializer.

## Workflow

1. Prepare master Raspberry Pi
   - Install VIDLOOP and verify playback/service.
   - Copy this repository to the Pi.

2. Install first boot service on master Pi
   - `sudo ./image-kit/install-firstboot-service.sh`

3. Clean master before cloning
   - `sudo ./image-kit/preclone-cleanup.sh`
   - Shut down the Pi after cleanup.

4. Build image on Linux host
   - Insert SD card into Linux machine.
   - Unmount all SD partitions.
   - Run: `sudo ./image-kit/build-master-image.sh /dev/sdX vidloop-v3-master-YYYYMMDD`

5. Flash clones
   - Flash `.img.xz` with Raspberry Pi Imager or balenaEtcher.

6. Optional hostname per device
   - Before first boot, place a file on boot partition:
     - `/boot/vidloop-hostname` (or `/boot/firmware/vidloop-hostname`)
     - Content example: `vidloop-rpi-entrada`

## First boot behavior in clones

- Regenerates `/etc/machine-id`
- Regenerates SSH host keys
- Sets optional hostname from boot file
- Ensures `video_looper.ini` points to `/home/admin/VIDLOOP44`
- Tries to enable/restart `video_looper`
- Disables itself after successful run

## Notes for pi_video_looper

Expected service name: `video_looper`
Expected config path (primary): `/opt/video_looper/video_looper.ini`
Expected video path: `/home/admin/VIDLOOP44`

If your install uses different paths, edit `firstboot-init.sh` accordingly.
