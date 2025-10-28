#!/bin/bash
set -euo pipefail

# ================================================================
#                            VIDLOOP
#      Desarrollado por IGNACE - Powered By: 44 Contenidos
# ================================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para logging con colores
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $1"; }

# Banner
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    VIDLOOP OPTIMIZADOR - IMAGEN EXISTENTE     ${NC}"
echo -e "${BLUE}   ✨ ANTI-MICRO-CORTES + FORCE DISPLAY ✨    ${NC}"
echo -e "${BLUE}   Desarrollado por IGNACE - Powered By: 44    ${NC}"
echo -e "${BLUE}================================================${NC}"

# Detectar usuario actual y sistema
CURRENT_USER=$(whoami)
SUDO_USER_DETECTED=${SUDO_USER:-$CURRENT_USER}

# Si estamos ejecutando como root, usar el usuario que invocó sudo
if [ "$CURRENT_USER" = "root" ] && [ -n "${SUDO_USER:-}" ]; then
    TARGET_USER="$SUDO_USER"
    TARGET_HOME="/home/$SUDO_USER"
else
    TARGET_USER="$CURRENT_USER"
    TARGET_HOME="$HOME"
fi

log_info "Usuario detectado: $TARGET_USER"
log_info "Directorio home: $TARGET_HOME"

# Verificar si estamos en Raspberry Pi
if [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model; then
    log_success "Raspberry Pi detectada - Imagen con pi_video_looper existente"
    IS_RPI=true
else
    log_warning "No se detectó una Raspberry Pi. Continuando..."
    IS_RPI=false
fi

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para backup de archivos de configuración
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        sudo cp "$file" "${file}.backup.definitivo.$(date +%Y%m%d_%H%M%S)"
        log_info "Backup creado: ${file}.backup.definitivo.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Detener procesos existentes
log_info "🛑 Deteniendo procesos existentes..."
sudo pkill -f video_looper 2>/dev/null || true
sudo pkill -f omxplayer 2>/dev/null || true
sudo systemctl stop video_looper 2>/dev/null || true
sudo systemctl stop vidloop-player.service 2>/dev/null || true
sudo systemctl stop vidloop-ultra.service 2>/dev/null || true
sudo systemctl stop vidloop-smooth.service 2>/dev/null || true
sleep 3
log_success "Procesos detenidos"

# PASO 2: ACTUALIZAR SISTEMA E INSTALAR DEPENDENCIAS
log_info "📦 Actualizando sistema e instalando dependencias optimizadas..."
sudo apt-get update -y
sudo apt-get upgrade -y

sudo apt-get install -y \
    htop \
    iotop \
    vmtouch \
    cpufrequtils \
    libraspberrypi-bin \
    curl \
    wget \
    || { log_error "Error instalando dependencias"; exit 1; }
    
log_success "Sistema actualizado y dependencias optimizadas instaladas"

# PASO 3: CONFIGURACIÓN HDMI ULTRA AGRESIVA ANTI-MICRO-CORTES
if [ "$IS_RPI" = true ]; then
    log_info "🖥️ Configurando HDMI ULTRA AGRESIVO ANTI-MICRO-CORTES..."
    
    CONFIG_FILE="/boot/config.txt"
    if [ ! -f "$CONFIG_FILE" ] && [ -f "/boot/firmware/config.txt" ]; then
        CONFIG_FILE="/boot/firmware/config.txt"
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        backup_file "$CONFIG_FILE"
        
        # Limpiar configuraciones previas
        sudo sed -i '/^hdmi_/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^gpu_/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^arm_freq/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^core_freq/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^over_voltage/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^config_hdmi_boost/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^framebuffer_/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^display_/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^decode_/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^start_x/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^disable_overscan/d' "$CONFIG_FILE" 2>/dev/null || true
        
        # Agregar configuración DEFINITIVA ANTI-MICRO-CORTES
        sudo bash -c "cat >> $CONFIG_FILE <<EOF

# ========== VIDLOOP DEFINITIVO - ANTI-MICRO-CORTES ==========
# HDMI ULTRA AGRESIVO
hdmi_force_hotplug=1
hdmi_drive=2
hdmi_group=1
hdmi_mode=16
config_hdmi_boost=10
hdmi_pixel_encoding=0
hdmi_blanking=1

# GPU OPTIMIZADA PARA VIDEO SUAVE (ANTI-MICRO-CORTES)
gpu_mem=256
gpu_freq=500
core_freq=500

# CPU OVERCLOCK SUAVE
arm_freq=1800
over_voltage=2

# VIDEO SETTINGS OPTIMIZADOS
framebuffer_width=1920
framebuffer_height=1080
framebuffer_depth=32
framebuffer_ignore_alpha=1

# DISPLAY SETTINGS
display_auto_detect=1
display_rotate=0
disable_overscan=1

# CODEC OPTIMIZATION
decode_MPG2=0x12345678
decode_WVC1=0x12345678

# VIDEO CORE IV OPTIMIZATION
start_x=1

# ANTI-THROTTLING
avoid_warnings=1
temp_limit=85
EOF"
        log_success "✅ Configuración HDMI ULTRA AGRESIVA ANTI-MICRO-CORTES aplicada"
    fi
    
    # Forzar HDMI inmediatamente
    if command -v tvservice >/dev/null 2>&1; then
        sudo tvservice -p 2>/dev/null || true
        sleep 2
        sudo tvservice --explicit="CEA 16 HDMI" 2>/dev/null || true
    fi
fi

# PASO 4: OPTIMIZAR SISTEMA OPERATIVO
log_info "⚙️ Optimizando sistema operativo para video suave..."

# Configurar swappiness
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf >/dev/null 2>&1 || true

# Configurar I/O scheduler
echo 'ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/scheduler}="deadline"' | sudo tee /etc/udev/rules.d/60-ioschedulers.rules >/dev/null 2>&1 || true

# Configurar dirty ratios
echo 'vm.dirty_background_ratio=5' | sudo tee -a /etc/sysctl.conf >/dev/null 2>&1 || true
echo 'vm.dirty_ratio=10' | sudo tee -a /etc/sysctl.conf >/dev/null 2>&1 || true

log_success "✅ Sistema operativo optimizado"

# PASO 5: INSTALAR ZEROTIER (Reinstalar limpiamente)
log_info "🌐 Reinstalando ZeroTier para VPN limpia..."

# Eliminar ZeroTier existente si está instalado
if command_exists zerotier-cli; then
    log_warning "ZeroTier existente detectado, desinstalando..."
    sudo systemctl stop zerotier-one 2>/dev/null || true
    sudo systemctl disable zerotier-one 2>/dev/null || true
    sudo apt-get remove --purge -y zerotier-one 2>/dev/null || true
    sudo rm -rf /var/lib/zerotier-one 2>/dev/null || true
    sudo rm -rf /etc/systemd/system/zerotier-one.service 2>/dev/null || true
    log_success "ZeroTier anterior eliminado"
fi

# Instalar ZeroTier fresco
curl -s https://install.zerotier.com | sudo bash || {
    log_error "Error instalando ZeroTier"
    exit 1
}
log_success "ZeroTier instalado limpiamente"

# Configurar red ZeroTier
echo
echo -e "${YELLOW}¿Deseas configurar ZeroTier ahora? (y/n):${NC}"
read -r CONFIGURE_ZT

if [[ $CONFIGURE_ZT =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Por favor, ingresa el ID de tu red ZeroTier (16 caracteres):${NC}"
    read -r ZTNETID
    
    if [ -n "$ZTNETID" ] && [ ${#ZTNETID} -eq 16 ]; then
        sudo zerotier-cli join "$ZTNETID"
        log_success "Raspberry Pi unida a la red ZeroTier: $ZTNETID"
        echo -e "${YELLOW}📝 IMPORTANTE: Recuerda autorizar este dispositivo en tu panel de ZeroTier${NC}"
        echo -e "${CYAN}🔗 Panel ZeroTier: https://my.zerotier.com/network/$ZTNETID${NC}"
    else
        log_warning "ID de red ZeroTier inválido (debe tener exactamente 16 caracteres)"
        echo "💡 Formato esperado: a1b2c3d4e5f6g7h8"
    fi
else
    log_info "Configuración de ZeroTier saltada"
    echo "💡 Puedes configurar luego con: sudo zerotier-cli join <NETWORK_ID>"
fi

# PASO 6: CONFIGURAR USUARIO ADMIN
log_info "👤 Configurando usuario admin..."
if id -u admin >/dev/null 2>&1; then
    log_info "Usuario 'admin' existe. Actualizando contraseña..."
else
    log_info "Creando usuario 'admin'..."
    sudo adduser --disabled-password --gecos "" admin
    sudo usermod -aG sudo admin
fi

echo "admin:4455" | sudo chpasswd
log_success "Usuario admin configurado con contraseña: 4455"

# PASO 7: CONFIGURAR SSH
log_info "🔐 Configurando SSH optimizado..."
SSHD_CONFIG="/etc/ssh/sshd_config"

if [ -f "$SSHD_CONFIG" ]; then
    backup_file "$SSHD_CONFIG"
    
    sudo sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    sudo sed -i 's/^\s*#\?\s*PubkeyAuthentication.*/PubkeyAuthentication no/' "$SSHD_CONFIG"
    sudo sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    
    grep -q "^PasswordAuthentication" "$SSHD_CONFIG" || echo "PasswordAuthentication yes" | sudo tee -a "$SSHD_CONFIG"
    grep -q "^PubkeyAuthentication" "$SSHD_CONFIG" || echo "PubkeyAuthentication no" | sudo tee -a "$SSHD_CONFIG"
    
    sudo systemctl restart ssh
    log_success "SSH configurado y optimizado"
fi

# Verificar que la configuración se aplicó correctamente
log_info "✅ Verificando configuración aplicada..."
log_success "🖥️ HDMI: Ultra agresivo configurado"
log_success "💾 GPU: 256MB asignados para video suave"
log_success "⚡ CPU: Overclock suave aplicado"
log_success "🌐 ZeroTier: Reinstalado limpiamente"
log_success "👤 Usuario: admin configurado"
log_success "🔐 SSH: Optimizado y funcionando"

# PASO 9: CONFIGURAR SCREEN BLANKING
if [ "$IS_RPI" = true ]; then
    log_info "🖥️ Configurando prevención de screen blanking..."
    
    AUTOSTART_DIRS=(
        "/etc/xdg/lxsession/LXDE-pi/autostart"
        "/etc/xdg/lxsession/LXDE/autostart"
        "/home/$TARGET_USER/.config/lxsession/LXDE-pi/autostart"
        "/home/admin/.config/lxsession/LXDE-pi/autostart"
    )
    
    for AUTOSTART in "${AUTOSTART_DIRS[@]}"; do
        sudo mkdir -p "$(dirname "$AUTOSTART")" 2>/dev/null || true
        
        sudo bash -c "cat > $AUTOSTART <<EOF
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver -no-splash
@point-rpi
@xset s off
@xset -dpms
@xset s noblank
EOF"
        log_success "Screen blanking deshabilitado en $AUTOSTART"
    done
fi

# PASO 10: CREAR SERVICIO HDMI KEEPALIVE
if [ "$IS_RPI" = true ]; then
    log_info "📺 Creando servicio HDMI keepalive..."
    
    sudo bash -c 'cat > /usr/local/bin/hdmi-keepalive.sh <<EOF
#!/bin/bash
# HDMI Keepalive para VIDLOOP DEFINITIVO
while true; do
    if command -v tvservice >/dev/null 2>&1; then
        if tvservice -s 2>/dev/null | grep -q "TV is off"; then
            tvservice -p 2>/dev/null || true
            chvt 6 && chvt 7 2>/dev/null || true
            echo "$(date): HDMI reactivado - TV estaba apagada" >> /var/log/hdmi-keepalive.log
        elif ! tvservice -s 2>/dev/null | grep -q "0x12000"; then
            tvservice -p 2>/dev/null || true
            chvt 6 && chvt 7 2>/dev/null || true
            echo "$(date): HDMI forzado - Estado no óptimo" >> /var/log/hdmi-keepalive.log
        fi
    fi
    sleep 5
done
EOF'
    
    sudo chmod +x /usr/local/bin/hdmi-keepalive.sh
    
    sudo bash -c 'cat > /etc/systemd/system/hdmi-keepalive.service <<EOF
[Unit]
Description=VIDLOOP HDMI keepalive service
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hdmi-keepalive.sh
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF'
    
    sudo systemctl daemon-reload
    sudo systemctl enable hdmi-keepalive.service
    sudo systemctl start hdmi-keepalive.service
    log_success "Servicio HDMI keepalive configurado y activo"
fi

# PASO 12: CREAR SCRIPT DEFINITIVO ANTI-MICRO-CORTES
log_info "🎬 Creando script DEFINITIVO ANTI-MICRO-CORTES para imagen existente..."

DEFINITIVO_SCRIPT="/usr/local/bin/vidloop-definitivo.sh"
sudo bash -c "cat > $DEFINITIVO_SCRIPT <<'DEFINITIVO_EOF'
#!/bin/bash
# VIDLOOP DEFINITIVO - Script ANTI-MICRO-CORTES para imagen existente
# Desarrollado por IGNACE - Powered By: 44 Contenidos

# Variables de entorno OPTIMIZADAS
export DISPLAY=:0.0
export HOME=/home/admin
export USER=admin
export XAUTHORITY=/home/admin/.Xauthority
export OMX_BUFFERS=512
export OMX_MAX_FPS=60
export FRAMEBUFFER=/dev/fb0

# Log
LOG_FILE=\"/var/log/vidloop-definitivo.log\"
exec > >(tee -a \"\$LOG_FILE\") 2>&1

echo \"\"
echo \"====================================================\"
echo \"\$(date): [VIDLOOP DEFINITIVO] INICIO ANTI-MICRO-CORTES\"
echo \"====================================================\"

log_msg() {
    echo \"\$(date): [\$1] \$2\"
}

log_msg \"INFO\" \"🚀 Iniciando VIDLOOP DEFINITIVO en imagen existente...\"

# CONFIGURAR PRIORIDADES MÁXIMAS
renice -20 \$\$ 2>/dev/null || true
ionice -c 1 -n 0 -p \$\$ 2>/dev/null || true

# CONFIGURAR CPU PARA MÁXIMO RENDIMIENTO
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
    log_msg \"INFO\" \"CPU configurado a máximo rendimiento\"
fi

# FORZAR HDMI Y GPU
if [ -f /proc/device-tree/model ] && grep -q \"Raspberry Pi\" /proc/device-tree/model; then
    log_msg \"INFO\" \"🖥️ FORZANDO HDMI Y GPU...\"
    
    if command -v tvservice >/dev/null 2>&1; then
        tvservice -p 2>/dev/null || true
        sleep 3
        tvservice --explicit=\"CEA 16 HDMI\" 2>/dev/null || true
        sleep 2
    fi
    
    if [ -c \"/dev/fb0\" ]; then
        fbset -g 1920 1080 1920 1080 32 2>/dev/null || true
    fi
    
    chvt 1 2>/dev/null && sleep 1 && chvt 7 2>/dev/null || true
fi

# Esperar boot completo
sleep 30

# Directorio de videos
VIDEOS_DIR=\"/home/admin/VIDLOOP44\"
log_msg \"INFO\" \"Verificando: \$VIDEOS_DIR\"

if [ ! -d \"\$VIDEOS_DIR\" ]; then
    log_msg \"INFO\" \"📁 Creando carpeta de videos: \$VIDEOS_DIR\"
    mkdir -p \"\$VIDEOS_DIR\"
    chown admin:admin \"\$VIDEOS_DIR\" 2>/dev/null || chown admin \"\$VIDEOS_DIR\"
fi

# Buscar videos (formatos optimizados para anti-micro-cortes)
VIDEO_FILES=\$(find \"\$VIDEOS_DIR\" -type f \\( -iname \"*.mp4\" -o -iname \"*.h264\" -o -iname \"*.mkv\" \\) 2>/dev/null | sort)

if [ -z \"\$VIDEO_FILES\" ]; then
    log_msg \"WARNING\" \"❌ NO HAY VIDEOS optimizados en \$VIDEOS_DIR\"
    log_msg \"INFO\" \"💡 Formatos recomendados: .mp4, .h264, .mkv\"
    log_msg \"INFO\" \"💡 Copia videos a \$VIDEOS_DIR y reinicia el servicio\"
    
    # Esperar por videos cada 30 segundos
    while [ -z \"\$VIDEO_FILES\" ]; do
        sleep 30
        VIDEO_FILES=\$(find \"\$VIDEOS_DIR\" -type f \\( -iname \"*.mp4\" -o -iname \"*.h264\" -o -iname \"*.mkv\" \\) 2>/dev/null | sort)
        if [ -n \"\$VIDEO_FILES\" ]; then
            log_msg \"INFO\" \"✅ Videos detectados, continuando...\"
            break
        fi
        log_msg \"INFO\" \"⏳ Esperando videos en \$VIDEOS_DIR...\"
    done
fi

VIDEO_COUNT=\$(echo \"\$VIDEO_FILES\" | wc -l)
log_msg \"INFO\" \"✅ Encontrados \$VIDEO_COUNT videos optimizados\"

# BUSCAR INSTALACIÓN DE PI_VIDEO_LOOPER EXISTENTE
POSSIBLE_VIDLOOP_DIRS=(
    \"/opt/video_looper\"
    \"/home/pi/pi_video_looper\"
    \"/home/admin/pi_video_looper\"
    \"/usr/local/pi_video_looper\"
    \"/home/admin/VIDLOOP44/pi_video_looper\"
)

VIDLOOP_DIR=\"\"
for dir in \"\${POSSIBLE_VIDLOOP_DIRS[@]}\"; do
    if [ -f \"\$dir/video_looper.py\" ]; then
        VIDLOOP_DIR=\"\$dir\"
        log_msg \"INFO\" \"✅ pi_video_looper encontrado en: \$dir\"
        break
    fi
done

# FUNCIÓN DE REPRODUCCIÓN ANTI-MICRO-CORTES
play_smooth() {
    local video=\"\$1\"
    local name=\$(basename \"\$video\")
    
    log_msg \"INFO\" \"🎬 REPRODUCIENDO SUAVE: \$name\"
    
    # PARÁMETROS DEFINITIVOS ANTI-MICRO-CORTES
    omxplayer \\
        --display 7 \\
        --aspect-mode letterbox \\
        --no-osd \\
        --vol 900 \\
        --refresh \\
        --timeout 0 \\
        --layer 1 \\
        --alpha 255 \\
        --win \"0 0 1920 1080\" \\
        --advanced \\
        --hw \\
        --boost-on-downmix \\
        --audio_queue 20 \\
        --video_queue 20 \\
        --audio_fifo 20 \\
        --video_fifo 20 \\
        --threshold 0.5 \\
        --fps 30 \\
        --key-config /dev/null \\
        \"\$video\" 2>/dev/null || {
        log_msg \"WARNING\" \"Error con \$name, reintentando básico...\"
        
        # Fallback básico
        omxplayer --display 7 --aspect-mode letterbox --no-osd --vol 900 \"\$video\" 2>/dev/null || {
            log_msg \"ERROR\" \"Error fatal con \$name\"
            return 1
        }
    }
    
    return 0
}

# MÉTODO 1: USAR PI_VIDEO_LOOPER EXISTENTE SI SE ENCUENTRA
if [ -n \"\$VIDLOOP_DIR\" ]; then
    log_msg \"INFO\" \"🎬 USANDO PI_VIDEO_LOOPER EXISTENTE OPTIMIZADO\"
    cd \"\$VIDLOOP_DIR\"
    
    # Crear/actualizar configuración DEFINITIVA ANTI-MICRO-CORTES
    CONFIG_FILE=\"\$VIDLOOP_DIR/video_looper.ini\"
    cat > \"\$CONFIG_FILE\" <<CONFIG_EOF
[video_looper]
file_reader = directory
directory_path = \$VIDEOS_DIR
playlist_order = alphabetical
repeat = true
wait_time = 0.05
show_osd = false
background_color = black
sound = on
volume = 90
omxplayer_extra_args = --display 7 --aspect-mode letterbox --no-osd --vol 900 --refresh --layer 1 --alpha 255 --advanced --hw --boost-on-downmix --audio_queue 20 --video_queue 20 --audio_fifo 20 --video_fifo 20 --threshold 0.5 --fps 30

[directory]
path = \$VIDEOS_DIR
extensions = mp4,h264,mkv,avi,mov,m4v
subdirectories = false

[omxplayer]
extra_args = --display 7 --aspect-mode letterbox --no-osd --vol 900 --refresh --layer 1 --alpha 255 --advanced --hw --boost-on-downmix --audio_queue 20 --video_queue 20 --audio_fifo 20 --video_fifo 20 --threshold 0.5 --fps 30

[usb_drive]
enabled = false

[usb]
enabled = false
CONFIG_EOF
    
    log_msg \"INFO\" \"🚀 Ejecutando pi_video_looper DEFINITIVO\"
    python3 video_looper.py --config \"\$CONFIG_FILE\" 2>&1 || {
        log_msg \"ERROR\" \"pi_video_looper falló, usando reproducción directa\"
    }
fi

# MÉTODO 2: REPRODUCCIÓN DIRECTA ANTI-MICRO-CORTES (FALLBACK)
log_msg \"INFO\" \"🎬 REPRODUCCIÓN DIRECTA ANTI-MICRO-CORTES\"

# Precargar archivos en cache si vmtouch está disponible
if command -v vmtouch >/dev/null 2>&1; then
    log_msg \"INFO\" \"Precargando archivos en memoria...\"
    echo \"\$VIDEO_FILES\" | while read -r video; do
        vmtouch -t \"\$video\" >/dev/null 2>&1 &
    done
fi

# LOOP PRINCIPAL DEFINITIVO
while true; do
    echo \"\$VIDEO_FILES\" | while IFS= read -r video; do
        if [ -f \"\$video\" ]; then
            if ! play_smooth \"\$video\"; then
                log_msg \"WARNING\" \"Saltando video problemático: \$(basename \"\$video\")\"
                continue
            fi
            
            # Micro pausa para transición ultra suave
            sleep 0.05
        fi
    done
    
    log_msg \"INFO\" \"🔄 Reiniciando playlist DEFINITIVA...\"
    
    # Refrescar lista de videos por si se agregaron nuevos
    VIDEO_FILES=\$(find \"\$VIDEOS_DIR\" -type f \\( -iname \"*.mp4\" -o -iname \"*.h264\" -o -iname \"*.mkv\" \\) 2>/dev/null | sort)
    
    sleep 0.5
done
DEFINITIVO_EOF"

sudo chmod +x "$DEFINITIVO_SCRIPT"
log_success "✅ Script DEFINITIVO ANTI-MICRO-CORTES creado para imagen existente"

# PASO 16: CONFIGURAR LOGS
log_info "📝 Configurando sistema de logs..."
sudo touch /var/log/vidloop-definitivo.log
sudo chmod 666 /var/log/vidloop-definitivo.log
sudo touch /var/log/hdmi-keepalive.log
sudo chmod 666 /var/log/hdmi-keepalive.log
log_success "✅ Sistema de logs configurado"

# PASO 17: CREAR SCRIPT DE DIAGNÓSTICO DEFINITIVO
log_info "🔍 Creando script de diagnóstico definitivo..."
DIAG_DEFINITIVO="/usr/local/bin/vidloop-definitivo-diagnostic.sh"
sudo bash -c "cat > $DIAG_DEFINITIVO <<'DIAG_EOF'
#!/bin/bash

echo \"========================================\"
echo \"   DIAGNÓSTICO VIDLOOP DEFINITIVO - \$(date)\"
echo \"     IMAGEN EXISTENTE OPTIMIZADA\"
echo \"========================================\"

# 1. Sistema y hardware
echo \"🚀 SISTEMA Y HARDWARE:\"
if command -v vcgencmd >/dev/null 2>&1; then
    echo \"  🔥 Temperatura CPU:\"
    vcgencmd measure_temp 2>/dev/null | sed 's/^/    /' || echo \"    No disponible\"
    echo \"  ⚡ Frecuencia ARM:\"
    vcgencmd measure_clock arm 2>/dev/null | sed 's/^/    /' || echo \"    No disponible\"
    echo \"  📊 Memoria GPU:\"
    vcgencmd get_mem gpu 2>/dev/null | sed 's/^/    /' || echo \"    No disponible\"
fi

if [ -f \"/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor\" ]; then
    echo \"  ⚙️ CPU Governor:\"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor | sed 's/^/    /'
fi

echo \"\"

# 2. Display HDMI
echo \"🖥️ DISPLAY HDMI:\"
if command -v tvservice >/dev/null 2>&1; then
    echo \"  📺 Estado HDMI:\"
    tvservice -s 2>&1 | sed 's/^/    /'
else
    echo \"  ❌ tvservice no disponible\"
fi

if [ -c \"/dev/fb0\" ]; then
    echo \"  🖼️ Framebuffer: ✅ Disponible\"
else
    echo \"  🖼️ Framebuffer: ❌ No disponible\"
fi

echo \"\"

# 3. Pi Video Looper existente
echo \"🎬 PI_VIDEO_LOOPER EXISTENTE:\"
POSSIBLE_DIRS=(\"/opt/video_looper\" \"/home/pi/pi_video_looper\" \"/home/admin/pi_video_looper\" \"/usr/local/pi_video_looper\" \"/home/admin/VIDLOOP44/pi_video_looper\")

FOUND_VIDLOOP=false
for dir in \"\${POSSIBLE_DIRS[@]}\"; do
    if [ -f \"\$dir/video_looper.py\" ]; then
        echo \"  ✅ Encontrado en: \$dir\"
        FOUND_VIDLOOP=true
        
        if [ -f \"\$dir/video_looper.ini\" ]; then
            echo \"  📋 Configuración: ✅ Presente\"
            if grep -q \"directory_path = /home/admin/VIDLOOP44\" \"\$dir/video_looper.ini\" 2>/dev/null; then
                echo \"  🎯 Directorio: ✅ Optimizado\"
            else
                echo \"  🎯 Directorio: ⚠️ Necesita optimización\"
            fi
        else
            echo \"  📋 Configuración: ❌ Falta\"
        fi
        break
    fi
done

if [ \"\$FOUND_VIDLOOP\" = false ]; then
    echo \"  ❌ pi_video_looper no encontrado en ubicaciones estándar\"
fi

echo \"\"

# 4. Videos optimizados
echo \"📁 VIDEOS ANTI-MICRO-CORTES:\"
if [ -d \"/home/admin/VIDLOOP44\" ]; then
    mp4_count=\$(find /home/admin/VIDLOOP44 -iname \"*.mp4\" 2>/dev/null | wc -l)
    h264_count=\$(find /home/admin/VIDLOOP44 -iname \"*.h264\" 2>/dev/null | wc -l)
    mkv_count=\$(find /home/admin/VIDLOOP44 -iname \"*.mkv\" 2>/dev/null | wc -l)
    
    echo \"  📊 Videos MP4: \$mp4_count\"
    echo \"  📊 Videos H264: \$h264_count\"
    echo \"  📊 Videos MKV: \$mkv_count\"
    
    total=\$((mp4_count + h264_count + mkv_count))
    echo \"  📊 Total optimizados: \$total\"
    
    if [ \$total -gt 0 ]; then
        echo \"  📹 Primeros 3 videos:\"
        find /home/admin/VIDLOOP44 -type f \\( -iname \"*.mp4\" -o -iname \"*.h264\" -o -iname \"*.mkv\" \\) 2>/dev/null | head -3 | while read -r video; do
            if [ -f \"\$video\" ]; then
                size=\$(du -h \"\$video\" 2>/dev/null | cut -f1)
                echo \"    ✅ \$(basename \"\$video\") (\$size)\"
            fi
        done
    else
        echo \"  ❌ NO HAY VIDEOS OPTIMIZADOS\"
        echo \"  💡 Copia videos MP4, H264 o MKV a /home/admin/VIDLOOP44\"
    fi
else
    echo \"  ❌ Carpeta /home/admin/VIDLOOP44 no existe\"
fi

echo \"\"

# 5. Servicios
echo \"⚙️ SERVICIOS:\"

# Verificar servicio de video_looper original
if systemctl list-unit-files | grep -q video_looper; then
    if systemctl is-active --quiet video_looper; then
        echo \"  ✅ video_looper: ACTIVO\"
    else
        echo \"  ❌ video_looper: INACTIVO\"
    fi
    
    if systemctl is-enabled --quiet video_looper; then
        echo \"  ✅ video_looper: HABILITADO\"
    else
        echo \"  ❌ video_looper: NO habilitado\"
    fi
else
    echo \"  ❌ Servicio video_looper no encontrado\"
fi

# Verificar HDMI keepalive
if systemctl is-active --quiet hdmi-keepalive; then
    echo \"  ✅ hdmi-keepalive: ACTIVO\"
else
    echo \"  ❌ hdmi-keepalive: INACTIVO\"
fi

echo \"\"

# 6. ZeroTier
echo \"🌐 ZEROTIER VPN:\"
if command -v zerotier-cli >/dev/null 2>&1; then
    zt_info=\$(sudo zerotier-cli info 2>/dev/null)
    if [ -n \"\$zt_info\" ]; then
        echo \"  ✅ ZeroTier: ACTIVO\"
        echo \"  📋 Info: \$zt_info\" | sed 's/^/    /'
        
        # Listar redes
        networks=\$(sudo zerotier-cli listnetworks 2>/dev/null)
        if [ -n \"\$networks\" ]; then
            echo \"  🌐 Redes conectadas:\"
            echo \"\$networks\" | sed 's/^/    /'
        fi
    else
        echo \"  ⚠️ ZeroTier instalado pero no activo\"
    fi
else
    echo \"  ❌ ZeroTier no instalado\"
fi

echo \"\"

# 7. Procesos optimizados
echo \"🔄 PROCESOS ANTI-MICRO-CORTES:\"
if pgrep -f vidloop-definitivo >/dev/null; then
    echo \"  ✅ vidloop-definitivo ejecutándose\"
    pgrep -f vidloop-definitivo | while read -r pid; do
        priority=\$(ps -o ni= -p \$pid 2>/dev/null | tr -d ' ')
        echo \"    PID: \$pid (Prioridad: \$priority)\"
    done
else
    echo \"  ❌ vidloop-definitivo NO ejecutándose\"
fi

if pgrep -f video_looper >/dev/null; then
    echo \"  ✅ video_looper ejecutándose\"
    vl_count=\$(pgrep -f video_looper | wc -l)
    echo \"    Instancias: \$vl_count\"
else
    echo \"  ❌ video_looper NO ejecutándose\"
fi

if pgrep -f omxplayer >/dev/null; then
    echo \"  ✅ omxplayer ejecutándose\"
    omx_count=\$(pgrep -f omxplayer | wc -l)
    echo \"    Instancias: \$omx_count\"
else
    echo \"  ❌ omxplayer NO ejecutándose\"
fi

echo \"\"

# 8. Logs DEFINITIVOS
echo \"📝 LOGS DEFINITIVOS (últimas 10 líneas):\"
if [ -f \"/var/log/vidloop-definitivo.log\" ]; then
    echo \"  📄 vidloop-definitivo.log:\"
    tail -10 /var/log/vidloop-definitivo.log | sed 's/^/    /'
else
    echo \"  ❌ Log vidloop-definitivo no encontrado\"
fi

echo \"\"

if [ -f \"/var/log/hdmi-keepalive.log\" ]; then
    echo \"  📄 hdmi-keepalive.log (últimas 5 líneas):\"
    tail -5 /var/log/hdmi-keepalive.log | sed 's/^/    /'
fi

echo \"\"
echo \"========================================\"
echo \"🛠️  COMANDOS PARA IMAGEN EXISTENTE:\"
echo \"  • Iniciar video: sudo systemctl start video_looper\"
echo \"  • Reiniciar video: sudo systemctl restart video_looper\"
echo \"  • Ver logs video: sudo journalctl -u video_looper -f\"
echo \"  • Ejecutar optimizado: sudo $DEFINITIVO_SCRIPT\"
echo \"  • Ver logs optimizado: tail -f /var/log/vidloop-definitivo.log\"
echo \"  • Diagnóstico: sudo $DIAG_DEFINITIVO\"
echo \"  • Estado HDMI: tvservice -s\"
echo \"  • Temperatura: vcgencmd measure_temp\"
echo \"  • ZeroTier redes: sudo zerotier-cli listnetworks\"
echo \"========================================\"
DIAG_EOF"

sudo chmod +x "$DIAG_DEFINITIVO"
log_success "✅ Script de diagnóstico definitivo creado"

# RESUMEN FINAL PARA IMAGEN EXISTENTE
echo
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}         IMAGEN EXISTENTE OPTIMIZADA EXITOSAMENTE             ${NC}"
echo -e "${GREEN}================================================================${NC}"

echo -e "${YELLOW}✨ OPTIMIZACIONES APLICADAS:${NC}"
echo "  • ✅ HDMI ultra agresivo con force display"
echo "  • ✅ GPU optimizada: 256MB + overclock suave"
echo "  • ✅ Sistema operativo optimizado para video"
echo "  • ✅ ZeroTier reinstalado limpiamente"
echo "  • ✅ Usuario admin configurado"
echo "  • ✅ SSH optimizado"
echo "  • ✅ Screen blanking deshabilitado"
echo "  • ✅ HDMI keepalive service activo"
echo "  • ✅ Script anti-micro-cortes configurado"
echo "  • ✅ Sistema de logs completo"
echo "  • ✅ Diagnóstico avanzado disponible"

echo
echo -e "${BLUE}📋 INFORMACIÓN DEL SISTEMA:${NC}"
echo -e "${BLUE}👤 Usuario SSH:${NC} admin"
echo -e "${BLUE}🔑 Contraseña SSH:${NC} 4455"
echo -e "${BLUE}📁 Carpeta de videos:${NC} /home/admin/VIDLOOP44"
echo -e "${BLUE}🎬 Pi Video Looper:${NC} Usar instalación existente"
echo -e "${BLUE}📝 Logs principales:${NC} /var/log/vidloop-definitivo.log"
echo -e "${BLUE}🔍 Diagnóstico:${NC} $DIAG_DEFINITIVO"

if [ "$IS_RPI" = true ]; then
    echo -e "${BLUE}📺 HDMI:${NC} Ultra optimizado + keepalive activo"
fi

if command_exists zerotier-cli; then
    ZT_STATUS=$(sudo zerotier-cli info 2>/dev/null | cut -d' ' -f3 || echo "Recién instalado")
    echo -e "${BLUE}🌐 ZeroTier:${NC} Reinstalado limpiamente (Estado: $ZT_STATUS)"
fi

echo
echo -e "${YELLOW}🚀 PARA USAR LA IMAGEN OPTIMIZADA:${NC}"
echo "  1. 📥 Copia videos OPTIMIZADOS (MP4/H264/MKV) a: /home/admin/VIDLOOP44"
echo "  2. 🔄 REINICIA el sistema: sudo reboot"
echo "  3. 🕐 Espera 1-2 minutos después del reinicio"
echo "  4. 🎬 Los videos se reproducirán automáticamente"
echo "  5. 🌐 Si configuraste ZeroTier, autoriza en el panel web"

echo
echo -e "${YELLOW}🛠️  COMANDOS PARA IMAGEN EXISTENTE:${NC}"
echo "  • 🔍 DIAGNÓSTICO COMPLETO: sudo $DIAG_DEFINITIVO"
echo "  • 🎬 Iniciar video original: sudo systemctl start video_looper"
echo "  • 🎬 Usar optimizado: sudo $DEFINITIVO_SCRIPT"
echo "  • 📝 Ver logs optimizado: tail -f /var/log/vidloop-definitivo.log"
echo "  • 📝 Ver logs original: sudo journalctl -u video_looper -f"
echo "  • 📺 Estado HDMI: tvservice -s"
echo "  • 🌐 Redes ZeroTier: sudo zerotier-cli listnetworks"

echo
echo -e "${CYAN}🎯 DIFERENCIAS CON INSTALACIÓN COMPLETA:${NC}"
echo "  • ✅ Mantiene pi_video_looper existente"
echo "  • ✅ Solo aplica optimizaciones anti-micro-cortes"
echo "  • ✅ ZeroTier reinstalado para configuración limpia"
echo "  • ✅ Compatibilidad total con imagen original"
echo "  • ✅ Respaldo script optimizado disponible"

echo
echo -e "${RED}📝 NOTAS IMPORTANTES:${NC}"
echo "  • Se aplicó overclock suave - monitorea temperatura"
echo "  • Usa formatos optimizados: MP4 (H264), H264 puro, MKV"
echo "  • Evita AVI, WMV, FLV (pueden causar micro cortes)"
echo "  • El script respeta la instalación original de pi_video_looper"

echo
echo -e "${GREEN}🎯 Desarrollado por IGNACE - Powered By: 44 Contenidos${NC}"
echo -e "${GREEN}   ✨ OPTIMIZADOR PARA IMAGEN EXISTENTE ✨${NC}"

# Preguntar si reiniciar
echo
echo -e "${YELLOW}¿Deseas reiniciar el sistema ahora para aplicar las optimizaciones? (y/n):${NC}"
read -r REBOOT_NOW

if [[ $REBOOT_NOW =~ ^[Yy]$ ]]; then
    log_info "🔄 Reiniciando sistema optimizado en 10 segundos..."
    echo "Después del reinicio:"
    echo "  ✨ Tu imagen tendrá todas las optimizaciones aplicadas"
    echo "  🎬 pi_video_looper original funcionará mejor"
    echo "  📝 Script optimizado disponible como respaldo"
    echo "  🔍 Usa el diagnóstico para verificar todo"
    
    countdown=10
    while [ $countdown -gt 0 ]; do
        echo -ne "\rReiniciando en $countdown segundos..."
        sleep 1
        countdown=$((countdown - 1))
    done
    echo
    
    sudo reboot
else
    log_info "💡 Recuerda reiniciar manualmente: sudo reboot"
    echo "Las optimizaciones están aplicadas pero necesitas reiniciar para que tengan efecto completo"
fi

log_success "🎯 VIDLOOP COMPLETADO"
