#!/usr/bin/env bash
set -euo pipefail

# Install firstboot assets into a running master Raspberry Pi before imaging.
# Run on the master Pi:
#   sudo ./image-kit/install-firstboot-service.sh

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "[ERROR] Run as root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -m 0755 "$SCRIPT_DIR/firstboot-init.sh" /usr/local/bin/vidloop-firstboot.sh
install -m 0644 "$SCRIPT_DIR/systemd/vidloop-firstboot.service" /etc/systemd/system/vidloop-firstboot.service

rm -f /var/lib/vidloop-firstboot.done
systemctl daemon-reload
systemctl enable vidloop-firstboot.service

echo "[OK] VIDLOOP firstboot service installed and enabled."
