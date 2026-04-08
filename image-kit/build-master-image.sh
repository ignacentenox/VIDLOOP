#!/usr/bin/env bash
set -euo pipefail

# Create compressed master image from an SD card block device on Linux host.
# Example:
#   sudo ./image-kit/build-master-image.sh /dev/sdb vidloop-v3-master-2026-04-07

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "[ERROR] Run as root." >&2
  exit 1
fi

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <block-device> <output-name-without-extension>"
  echo "Example: $0 /dev/sdb vidloop-v3-master-2026-04-07"
  exit 1
fi

DEVICE="$1"
OUT_BASENAME="$2"
OUT_FILE="${OUT_BASENAME}.img.xz"

if [[ ! -b "$DEVICE" ]]; then
  echo "[ERROR] Device not found or not a block device: $DEVICE" >&2
  exit 1
fi

if lsblk -nr -o MOUNTPOINT "$DEVICE" | grep -qE '.+'; then
  echo "[ERROR] Device has mounted partitions. Unmount first." >&2
  lsblk "$DEVICE"
  exit 1
fi

if ! command -v xz >/dev/null 2>&1; then
  echo "[ERROR] xz not installed. Install xz-utils first." >&2
  exit 1
fi

echo "[INFO] Reading $DEVICE and writing $OUT_FILE ..."

dd if="$DEVICE" bs=4M status=progress iflag=fullblock | xz -T0 -9 > "$OUT_FILE"

echo "[OK] Image created: $OUT_FILE"
sha256sum "$OUT_FILE" > "${OUT_FILE}.sha256"
echo "[OK] SHA256 saved: ${OUT_FILE}.sha256"
