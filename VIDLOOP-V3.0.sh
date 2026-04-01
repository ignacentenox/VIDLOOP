#!/bin/bash
set -euo pipefail

# ================================================================
#                            VIDLOOP V3.0
#      Desarrollado por IGNACE - Powered By: 44 Contenidos
#     100% Compatible Raspberry Pi OS TRIXIE (2026)
# ================================================================

# Colores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Banner
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}          VIDLOOP OPTIMIZADOR V3.0             ${NC}"
echo -e "${BLUE}   ✨ ANTI-MICRO-CORTES + FORCE DISPLAY ✨      ${NC}"
echo -e "${BLUE}================================================${NC}"

# Detectar usuario real
CURRENT_USER=$(whoami)
TARGET_USER=${SUDO_USER:-$CURRENT_USER}
TARGET_HOME="/home/$TARGET_USER"

log_info "Usuario detectado: $TARGET_USER"
log_info "Home: $TARGET_HOME"

# Detectar Raspberry
if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    IS_RPI=true
    log_ok "Raspberry Pi detectada"
else
    IS_RPI=false
    log_warn "No estás en una Raspberry Pi, sigo igual"
fi

# -------------------------
# 1) ACTUALIZAR SISTEMA
# -------------------------
log_info "📦 Actualizando sistema..."
sudo apt update -y
sudo apt upgrade -y
log_ok "Sistema actualizado"

# -------------------------
# 2) INSTALAR DEPENDENCIAS (VERSIÓN TRIXIE)
# -------------------------
log_info "📦 Instalando dependencias compatibles Trixie..."

sudo apt install -y \
    htop \
    iotop \
    vmtouch \
    linux-cpupower \
    raspi-utils-core \
    raspi-utils-dt \
    curl \
    wget \
    || { log_error "Falló instalación de dependencias"; exit 1; }

log_ok "Dependencias instaladas sin errores"

# -------------------------
# 3) HDMI ULTRA AGRESIVO
# -------------------------
if [ "$IS_RPI" = true ]; then
    log_info "🖥️ Aplicando configuración HDMI ULTRA AGRESIVA..."

    CONFIG="/boot/config.txt"
    [ ! -f "$CONFIG" ] && CONFIG="/boot/firmware/config.txt"

    sudo cp "$CONFIG" "$CONFIG.backup.$(date +%s)"

    # Limpieza previa
    sudo sed -i '/hdmi_/d;/gpu_/d;/arm_freq/d;/over_voltage/d;/framebuffer_/d;/display_/d;/start_x/d;/avoid_warnings/d;/temp_limit/d' "$CONFIG"

    # Aplicar config
    sudo bash -c "cat >> $CONFIG <<EOF

# ================= VIDLOOP V3.0 =================
hdmi_force_hotplug=1
hdmi_drive=2
hdmi_group=1
hdmi_mode=16
config_hdmi_boost=10

gpu_mem=256
gpu_freq=500
core_freq=500

arm_freq=1800
over_voltage=2

framebuffer_width=1920
framebuffer_height=1080
framebuffer_depth=32

disable_overscan=1
start_x=1
avoid_warnings=1
temp_limit=85
EOF"

    log_ok "HDMI optimizado"

    if command -v tvservice >/dev/null; then
        tvservice -p || true
        sleep 2
        tvservice --explicit="CEA 16 HDMI" || true
    fi
fi

# -------------------------
# 4) OPTIMIZACIÓN KERNEL
# -------------------------
log_info "⚙️ Optimizando kernel y memoria..."

sudo bash -c "cat >> /etc/sysctl.conf <<EOF
vm.swappiness=10
vm.dirty_background_ratio=5
vm.dirty_ratio=10
EOF"

echo 'ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/scheduler}="deadline"' \
| sudo tee /etc/udev/rules.d/60-ioschedulers.rules >/dev/null

log_ok "Kernel optimizado"

# -------------------------
# 5) ZEROTIER LIMPIO
# -------------------------
log_info "🌐 Reinstalando ZeroTier..."

if command -v zerotier-cli >/dev/null; then
    sudo systemctl stop zerotier-one || true
    sudo apt remove --purge -y zerotier-one || true
fi

curl -s https://install.zerotier.com | sudo bash || {
    log_error "Error instalando ZeroTier"
    exit 1
}

log_ok "ZeroTier reinstalado correctamente"

# -------------------------
# 6) USUARIO ADMIN
# -------------------------
log_info "👤 Configurando usuario admin..."

if ! id -u admin >/dev/null 2>&1; then
    sudo adduser --disabled-password --gecos "" admin
    sudo usermod -aG sudo admin
fi

echo "admin:4455" | sudo chpasswd
log_ok "Usuario admin configurado"

# -------------------------
# 7) SSH
# -------------------------
log_info "🔐 Configurando SSH..."

sudo sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

sudo systemctl restart ssh
log_ok "SSH listo"

# -------------------------
# 8) SCREEN BLANKING OFF
# -------------------------
if [ "$IS_RPI" = true ]; then
    log_info "🖥️ Deshabilitando screen blanking..."

    AUTOSTART="/home/admin/.config/lxsession/LXDE-pi/autostart"
    sudo mkdir -p "$(dirname "$AUTOSTART")"

    sudo bash -c "cat > $AUTOSTART <<EOF
@xset s off
@xset -dpms
@xset s noblank
EOF"

    log_ok "Screen blanking desactivado"
fi

# -------------------------
# 9) HDMI KEEPALIVE
# -------------------------
if [ "$IS_RPI" = true ]; then
    log_info "📺 Creando servicio HDMI KeepAlive..."

    sudo bash -c 'cat > /usr/local/bin/hdmi-keepalive.sh <<EOF
#!/bin/bash
while true; do
    if tvservice -s | grep -q "TV is off"; then
        tvservice -p
        chvt 6 && chvt 7
    fi
    sleep 5
done
EOF'

    sudo chmod +x /usr/local/bin/hdmi-keepalive.sh

    sudo bash -c 'cat > /etc/systemd/system/hdmi-keepalive.service <<EOF
[Unit]
Description=HDMI KeepAlive
After=multi-user.target

[Service]
ExecStart=/usr/local/bin/hdmi-keepalive.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

    sudo systemctl daemon-reload
    sudo systemctl enable hdmi-keepalive
    sudo systemctl start hdmi-keepalive

    log_ok "HDMI keepalive activo"
fi

# -------------------------
# FIN – REINICIO
# -------------------------
echo
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}    VIDLOOP V3.0 – OPTIMIZACIÓN COMPLETA     ${NC}"
echo -e "${GREEN}==============================================${NC}"

echo -e "${YELLOW}Usuario SSH:${NC} admin"
echo -e "${YELLOW}Contraseña:${NC} 4455"
echo -e "${YELLOW}Carpeta videos:${NC} /home/admin/VIDLOOP44"

echo
read -p "¿Reiniciar ahora? (y/n): " R
if [[ "$R" =~ ^[Yy]$ ]]; then
    sudo reboot
else
    log_info "Reiniciá manualmente cuando quieras: sudo reboot"
fi
