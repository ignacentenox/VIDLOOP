#!/usr/bin/env bash
set -euo pipefail

# ================================================================
#                            VIDLOOP V3.0
#      Desarrollado por IGNACE - Powered By: 44 Contenidos
#         Perfil seguro e idempotente para Raspberry Pi OS
# ================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Falta el comando requerido: $1"
        exit 1
    fi
}

upsert_kv() {
    # Reemplaza o agrega una clave de config de forma idempotente.
    local file="$1"
    local key="$2"
    local value="$3"
    sudo touch "$file"
    if sudo grep -Eq "^[[:space:]]*${key}=" "$file"; then
        sudo sed -i "s|^[[:space:]]*${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" | sudo tee -a "$file" >/dev/null
    fi
}

append_once() {
    local file="$1"
    local line="$2"
    sudo touch "$file"
    if ! sudo grep -Fxq "$line" "$file"; then
        echo "$line" | sudo tee -a "$file" >/dev/null
    fi
}

is_true() {
    case "${1:-}" in
        1|true|TRUE|yes|YES|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}               VIDLOOP V3.0                    ${NC}"
echo -e "${BLUE}        Setup seguro + idempotente             ${NC}"
echo -e "${BLUE}================================================${NC}"

require_cmd sudo
require_cmd awk
require_cmd sed
require_cmd git

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CURRENT_USER=$(whoami)
TARGET_USER=${SUDO_USER:-$CURRENT_USER}
TARGET_HOME=$(eval echo "~${TARGET_USER}")

log_info "Usuario detectado: $TARGET_USER"
log_info "Home: $TARGET_HOME"

IS_RPI=false
if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    IS_RPI=true
    log_ok "Raspberry Pi detectada"
else
    log_warn "No estas en Raspberry Pi. Se aplican solo pasos compatibles."
fi

log_info "Actualizando paquetes..."
sudo apt update -y
if is_true "${VIDLOOP_FULL_UPGRADE:-true}"; then
    log_info "Aplicando full-upgrade (puede tardar)..."
    sudo apt full-upgrade -y
else
    log_warn "VIDLOOP_FULL_UPGRADE=false: se omite full-upgrade"
fi
log_ok "Indice de paquetes actualizado"

log_info "Instalando dependencias base..."
sudo apt install -y \
    htop \
    iotop \
    curl \
    wget \
    python3 \
    python3-pip \
    openssh-server \
    || { log_error "Fallo la instalacion de dependencias"; exit 1; }
log_ok "Dependencias base instaladas"

log_info "Instalando/validando pi_video_looper..."
if sudo systemctl list-unit-files | grep -q '^video_looper\.service'; then
    log_info "Servicio video_looper ya existe, se conserva instalacion"
else
    TMP_LOOPER_DIR="/tmp/pi_video_looper"
    rm -rf "$TMP_LOOPER_DIR"
    git clone --depth 1 https://github.com/adafruit/pi_video_looper.git "$TMP_LOOPER_DIR"
    sudo bash "$TMP_LOOPER_DIR/install.sh"
fi

if [ -f "$SCRIPT_DIR/video_looper.ini" ]; then
    sudo install -m 0644 "$SCRIPT_DIR/video_looper.ini" /opt/video_looper/video_looper.ini
    sudo sed -i 's|/home/pi/VIDLOOP44|/home/admin/VIDLOOP44|g' /opt/video_looper/video_looper.ini
    log_ok "video_looper.ini desplegado en /opt/video_looper/video_looper.ini"
else
    log_warn "No se encontro video_looper.ini junto al script, se mantiene config existente"
fi

sudo systemctl enable video_looper 2>/dev/null || true
sudo systemctl restart video_looper 2>/dev/null || true
log_ok "pi_video_looper listo"

if is_true "$IS_RPI"; then
    log_info "Aplicando configuracion HDMI segura..."

    CONFIG="/boot/config.txt"
    if [ ! -f "$CONFIG" ]; then
        CONFIG="/boot/firmware/config.txt"
    fi

    sudo cp "$CONFIG" "$CONFIG.backup.$(date +%s)"
    upsert_kv "$CONFIG" "hdmi_force_hotplug" "1"
    upsert_kv "$CONFIG" "hdmi_drive" "2"
    upsert_kv "$CONFIG" "hdmi_group" "1"
    upsert_kv "$CONFIG" "hdmi_mode" "16"
    upsert_kv "$CONFIG" "disable_overscan" "1"

    if is_true "${VIDLOOP_AGGRESSIVE_TUNING:-false}"; then
        log_warn "Perfil agresivo activado por VIDLOOP_AGGRESSIVE_TUNING=true"
        upsert_kv "$CONFIG" "gpu_mem" "256"
        upsert_kv "$CONFIG" "arm_freq" "1800"
        upsert_kv "$CONFIG" "over_voltage" "2"
    else
        log_info "Perfil conservador activo (recomendado para produccion)."
    fi

    log_ok "HDMI configurado"
fi

log_info "Aplicando tuning de kernel idempotente..."
SYSCTL_FILE="/etc/sysctl.d/99-vidloop.conf"
sudo tee "$SYSCTL_FILE" >/dev/null <<'EOF'
vm.swappiness=10
vm.dirty_background_ratio=5
vm.dirty_ratio=10
EOF
sudo sysctl --system >/dev/null

UDEV_FILE="/etc/udev/rules.d/60-ioschedulers.rules"
echo 'ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/scheduler}="deadline"' | sudo tee "$UDEV_FILE" >/dev/null
sudo udevadm control --reload-rules || true
log_ok "Kernel y reglas I/O aplicadas"

log_info "Instalando ZeroTier (metodo APT)..."
if sudo apt install -y zerotier-one; then
    sudo systemctl enable --now zerotier-one
    log_ok "ZeroTier instalado y activo"
else
    log_warn "No se pudo instalar zerotier-one desde APT."
    log_warn "Instalalo manualmente con un metodo firmado por tu organizacion."
fi

log_info "Configurando usuario admin..."
if ! id -u admin >/dev/null 2>&1; then
    sudo adduser --disabled-password --gecos "" admin
    sudo usermod -aG sudo admin
fi

while true; do
    read -rsp "Ingresa nueva clave para usuario admin: " ADMIN_PASS
    echo
    read -rsp "Confirma clave para usuario admin: " ADMIN_PASS_CONFIRM
    echo
    if [ -z "$ADMIN_PASS" ]; then
        log_warn "La clave no puede estar vacia"
        continue
    fi
    if [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ]; then
        log_warn "Las claves no coinciden, intenta de nuevo"
        continue
    fi
    break
done

echo "admin:${ADMIN_PASS}" | sudo chpasswd
unset ADMIN_PASS ADMIN_PASS_CONFIRM
log_ok "Usuario admin configurado"

VIDEO_DIR="/home/admin/VIDLOOP44"
sudo mkdir -p "$VIDEO_DIR"
sudo chown -R admin:admin "$VIDEO_DIR"
log_ok "Carpeta de videos lista en $VIDEO_DIR"

log_info "Endureciendo SSH..."
SSHD="/etc/ssh/sshd_config"
sudo cp "$SSHD" "${SSHD}.bak.$(date +%s)"

if is_true "${ENABLE_SSH_PASSWORD_AUTH:-false}"; then
    upsert_kv "$SSHD" "PasswordAuthentication" "yes"
    log_warn "PasswordAuthentication habilitado por ENABLE_SSH_PASSWORD_AUTH=true"
else
    upsert_kv "$SSHD" "PasswordAuthentication" "no"
fi
upsert_kv "$SSHD" "PermitRootLogin" "no"

if sudo systemctl list-unit-files | grep -q '^ssh\.service'; then
    sudo systemctl restart ssh
elif sudo systemctl list-unit-files | grep -q '^sshd\.service'; then
    sudo systemctl restart sshd
fi
log_ok "SSH configurado"

if is_true "$IS_RPI"; then
    log_info "Configurando screen blanking off..."
    AUTOSTART="/home/admin/.config/lxsession/LXDE-pi/autostart"
    sudo mkdir -p "$(dirname "$AUTOSTART")"
    append_once "$AUTOSTART" "@xset s off"
    append_once "$AUTOSTART" "@xset -dpms"
    append_once "$AUTOSTART" "@xset s noblank"
    log_ok "Screen blanking desactivado"
fi

if is_true "$IS_RPI" && command -v tvservice >/dev/null 2>&1; then
    log_info "Creando servicio HDMI keepalive..."

    sudo tee /usr/local/bin/hdmi-keepalive.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
while true; do
    if tvservice -s 2>/dev/null | grep -q "TV is off"; then
        tvservice -p || true
        chvt 6 && chvt 7 || true
    fi
    sleep 5
done
EOF
    sudo chmod +x /usr/local/bin/hdmi-keepalive.sh

    sudo tee /etc/systemd/system/hdmi-keepalive.service >/dev/null <<'EOF'
[Unit]
Description=HDMI KeepAlive
After=multi-user.target

[Service]
ExecStart=/usr/local/bin/hdmi-keepalive.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now hdmi-keepalive.service
    log_ok "HDMI keepalive activo"
else
    log_warn "tvservice no disponible: se omite servicio HDMI keepalive"
fi

echo
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}     VIDLOOP V3.0 - SETUP COMPLETADO          ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "${YELLOW}Usuario SSH:${NC} admin"
echo -e "${YELLOW}Carpeta videos:${NC} /home/admin/VIDLOOP44"
echo -e "${YELLOW}Nota:${NC} PasswordAuthentication por defecto queda en NO"

echo
read -rp "Reiniciar ahora? (y/n): " R
if [[ "$R" =~ ^[Yy]$ ]]; then
    sudo reboot
else
    log_info "Reinicia manualmente cuando quieras: sudo reboot"
fi
