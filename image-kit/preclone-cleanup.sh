#!/usr/bin/env bash
set -euo pipefail

# Prepare a Raspberry Pi master installation before cloning to .img.
# Run this on the Raspberry Pi MASTER image just before powering off.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  log_error "Run as root: sudo ./image-kit/preclone-cleanup.sh"
  exit 1
fi

log_info "Stopping noisy services before cleanup..."
systemctl stop video_looper 2>/dev/null || true
systemctl stop zerotier-one 2>/dev/null || true

log_info "Cleaning machine identity..."
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

log_info "Removing host SSH keys (regenerated on first boot)..."
rm -f /etc/ssh/ssh_host_*

log_info "Cleaning shell and apt artifacts..."
rm -f /root/.bash_history /home/admin/.bash_history /home/pi/.bash_history 2>/dev/null || true
apt-get clean
rm -rf /var/lib/apt/lists/*

log_info "Cleaning transient logs..."
find /var/log -type f -name '*.log' -exec truncate -s 0 {} \; 2>/dev/null || true
journalctl --rotate || true
journalctl --vacuum-time=1s || true

log_info "Resetting cloud/network leftovers if present..."
rm -f /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null || true
rm -f /var/lib/zerotier-one/identity.secret 2>/dev/null || true

log_info "Ensuring video directory and ownership..."
mkdir -p /home/admin/VIDLOOP44
chown -R admin:admin /home/admin/VIDLOOP44

log_ok "Master cleanup complete."
log_warn "Now shutdown and clone the SD card to generate the master image."
