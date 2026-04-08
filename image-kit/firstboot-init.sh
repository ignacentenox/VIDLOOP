#!/usr/bin/env bash
set -euo pipefail

# One-shot first boot initializer for cloned VIDLOOP images.
# - Regenerates SSH host keys
# - Ensures machine-id exists
# - Optionally sets hostname from /boot/vidloop-hostname
# - Ensures video_looper.ini points to /home/admin/VIDLOOP44
# - Disables itself after success

LOG_FILE="/var/log/vidloop-firstboot.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] VIDLOOP firstboot init started"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "[ERROR] Must run as root"
  exit 1
fi

if [[ ! -s /etc/machine-id ]]; then
  systemd-machine-id-setup
  echo "[OK] machine-id generated"
fi

if ls /etc/ssh/ssh_host_* >/dev/null 2>&1; then
  rm -f /etc/ssh/ssh_host_*
fi
ssh-keygen -A
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
echo "[OK] SSH host keys regenerated"

for cfg in /opt/video_looper/video_looper.ini /home/admin/video_looper.ini /home/pi/video_looper.ini; do
  if [[ -f "$cfg" ]]; then
    sed -i 's|^directory_path\s*=.*|directory_path = /home/admin/VIDLOOP44|' "$cfg"
    if grep -q '^\[directory\]' "$cfg"; then
      sed -i 's|^path\s*=.*|path = /home/admin/VIDLOOP44|' "$cfg"
    fi
    echo "[OK] Updated video path in $cfg"
  fi
done

mkdir -p /home/admin/VIDLOOP44
chown -R admin:admin /home/admin/VIDLOOP44

HOSTNAME_FILE="/boot/firmware/vidloop-hostname"
[[ -f /boot/vidloop-hostname ]] && HOSTNAME_FILE="/boot/vidloop-hostname"
if [[ -f "$HOSTNAME_FILE" ]]; then
  NEW_HOSTNAME="$(tr -d '[:space:]' < "$HOSTNAME_FILE")"
  if [[ -n "$NEW_HOSTNAME" ]]; then
    hostnamectl set-hostname "$NEW_HOSTNAME"
    echo "[OK] Hostname set to $NEW_HOSTNAME"
  fi
fi

systemctl enable video_looper 2>/dev/null || true
systemctl restart video_looper 2>/dev/null || true

touch /var/lib/vidloop-firstboot.done
systemctl disable vidloop-firstboot.service
rm -f /etc/systemd/system/vidloop-firstboot.service
systemctl daemon-reload

echo "[OK] VIDLOOP firstboot init completed"
