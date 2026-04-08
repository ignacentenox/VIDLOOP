#!/usr/bin/env bash
set -euo pipefail

# Build a VIDLOOP release image from Raspberry Pi OS Lite Legacy (armhf) on GitHub Actions.
# The image is pre-provisioned to run VIDLOOP-V3.0.sh automatically on first boot.

WORKDIR="${WORKDIR:-$PWD/.work-image}"
OUTPUT_DIR="${OUTPUT_DIR:-$PWD/dist}"
IMAGE_URL="${IMAGE_URL:-https://downloads.raspberrypi.com/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2022-01-28/2022-01-28-raspios-buster-armhf-lite.zip}"
RELEASE_NAME="${RELEASE_NAME:-vidloop-rpios-legacy-armhf}"

mkdir -p "$WORKDIR" "$OUTPUT_DIR"
cd "$WORKDIR"

echo "[INFO] Downloading base Raspberry Pi OS image..."
curl -L "$IMAGE_URL" -o base.zip
unzip -o base.zip
BASE_IMG="$(find . -maxdepth 1 -type f -name '*.img' | head -n1)"
if [[ -z "$BASE_IMG" ]]; then
  echo "[ERROR] No .img file found after unzip" >&2
  exit 1
fi

echo "[INFO] Attaching loop device..."
LOOP_DEV="$(sudo losetup -Pf --show "$BASE_IMG")"
BOOT_PART="${LOOP_DEV}p1"
ROOT_PART="${LOOP_DEV}p2"

cleanup() {
  set +e
  sync
  sudo umount "$WORKDIR/mnt/boot" >/dev/null 2>&1 || true
  sudo umount "$WORKDIR/mnt/root" >/dev/null 2>&1 || true
  sudo losetup -d "$LOOP_DEV" >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$WORKDIR/mnt/root" "$WORKDIR/mnt/boot"
sudo mount "$ROOT_PART" "$WORKDIR/mnt/root"
sudo mount "$BOOT_PART" "$WORKDIR/mnt/boot"

echo "[INFO] Injecting VIDLOOP payload..."
sudo mkdir -p "$WORKDIR/mnt/root/opt/vidloop"
# Copy repository content except .git and CI working dirs.
sudo rsync -a --delete \
  --exclude='.git' \
  --exclude='.github' \
  --exclude='.work-image' \
  --exclude='dist' \
  "$GITHUB_WORKSPACE/" "$WORKDIR/mnt/root/opt/vidloop/"

sudo tee "$WORKDIR/mnt/root/usr/local/bin/vidloop-autoprovision.sh" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOG=/var/log/vidloop-autoprovision.log
exec > >(tee -a "$LOG") 2>&1

if [[ -f /var/lib/vidloop-autoprovision.done ]]; then
  exit 0
fi

echo "[INFO] VIDLOOP autoprovision started"

# Optional settings from boot partition.
if [[ -f /boot/firmware/vidloop.env ]]; then
  # shellcheck disable=SC1091
  source /boot/firmware/vidloop.env
elif [[ -f /boot/vidloop.env ]]; then
  # shellcheck disable=SC1091
  source /boot/vidloop.env
fi

cd /opt/vidloop
chmod +x VIDLOOP-V3.0.sh

# Defaults suitable for first boot provisioning.
export VIDLOOP_NONINTERACTIVE="${VIDLOOP_NONINTERACTIVE:-true}"
export VIDLOOP_AUTO_REBOOT="${VIDLOOP_AUTO_REBOOT:-false}"
export VIDLOOP_FULL_UPGRADE="${VIDLOOP_FULL_UPGRADE:-true}"

sudo bash ./VIDLOOP-V3.0.sh

touch /var/lib/vidloop-autoprovision.done
systemctl disable vidloop-autoprovision.service || true

echo "[INFO] VIDLOOP autoprovision completed"
EOF
sudo chmod +x "$WORKDIR/mnt/root/usr/local/bin/vidloop-autoprovision.sh"

sudo tee "$WORKDIR/mnt/root/etc/systemd/system/vidloop-autoprovision.service" >/dev/null <<'EOF'
[Unit]
Description=VIDLOOP one-shot autoprovision
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/vidloop-autoprovision.done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vidloop-autoprovision.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir -p "$WORKDIR/mnt/root/etc/systemd/system/multi-user.target.wants"
sudo ln -sf ../vidloop-autoprovision.service \
  "$WORKDIR/mnt/root/etc/systemd/system/multi-user.target.wants/vidloop-autoprovision.service"

# Template so users can customize first boot behavior without reflashing.
sudo tee "$WORKDIR/mnt/boot/vidloop.env.example" >/dev/null <<'EOF'
# Copy as vidloop.env and adjust values to customize first boot provisioning.
# Example path: /boot/vidloop.env or /boot/firmware/vidloop.env

# VIDLOOP_ADMIN_PASS=TuPasswordSeguro
# ENABLE_WIREGUARD=true
# VIDLOOP_WG_INTERFACE=wg0
# VIDLOOP_WG_CONFIG_B64=<base64 de wg0.conf>
# ENABLE_SSH_PASSWORD_AUTH=true
# VIDLOOP_AGGRESSIVE_TUNING=false
EOF

sync
sudo umount "$WORKDIR/mnt/boot"
sudo umount "$WORKDIR/mnt/root"
sudo losetup -d "$LOOP_DEV"
trap - EXIT

echo "[INFO] Compressing image..."
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_IMG="$OUTPUT_DIR/${RELEASE_NAME}-${STAMP}.img"
cp "$BASE_IMG" "$OUT_IMG"
xz -T0 -9 "$OUT_IMG"
sha256sum "$OUT_IMG.xz" > "$OUT_IMG.xz.sha256"

echo "[OK] Build complete"
ls -lh "$OUTPUT_DIR"
