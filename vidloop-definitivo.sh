#!/bin/bash
set -euo pipefail

# ================================================================
#           VIDLOOP DEFINITIVO - INSTALADOR COMPLETO
#    Combina: Setup + Anti-Micro-Cortes + Force Display
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
echo -e "${BLUE}    VIDLOOP DEFINITIVO - RASPBERRY PI SETUP   ${NC}"
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
    log_success "Raspberry Pi detectada"
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

# PASO 1: LIMPIEZA INICIAL
log_info "🧹 Realizando limpieza inicial..."

# Detener procesos existentes
sudo pkill -f video_looper 2>/dev/null || true
sudo pkill -f omxplayer 2>/dev/null || true
sudo systemctl stop vidloop-player.service 2>/dev/null || true
sudo systemctl stop vidloop-ultra.service 2>/dev/null || true
sudo systemctl stop vidloop-smooth.service 2>/dev/null || true
sleep 3

# Limpiar directorios problemáticos
if [ -d "pi_video_looper" ]; then
    sudo chmod -R 755 pi_video_looper 2>/dev/null || true
    sudo rm -rf pi_video_looper 2>/dev/null || sudo mv pi_video_looper "pi_video_looper_backup_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
fi

log_success "Limpieza inicial completada"

# PASO 2: ACTUALIZAR SISTEMA E INSTALAR DEPENDENCIAS
log_info "📦 Actualizando sistema e instalando dependencias..."
sudo apt-get update -y
sudo apt-get upgrade -y

sudo apt-get install -y \
    git \
    python3 \
    python3-pip \
    ffmpeg \
    curl \
    wget \
    build-essential \
    python3-dev \
    htop \
    iotop \
    vmtouch \
    cpufrequtils \
    libraspberrypi-bin \
    || { log_error "Error instalando dependencias"; exit 1; }
    
log_success "Sistema actualizado y dependencias instaladas"

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

# PASO 5: INSTALAR ZEROTIER
log_info "🌐 Instalando ZeroTier para VPN..."
if ! command_exists zerotier-cli; then
    curl -s https://install.zerotier.com | sudo bash || {
        log_error "Error instalando ZeroTier"
        exit 1
    }
    log_success "ZeroTier instalado"
else
    log_info "ZeroTier ya está instalado"
fi

# Configurar red ZeroTier
echo
echo -e "${YELLOW}¿Deseas configurar ZeroTier ahora? (y/n):${NC}"
read -r CONFIGURE_ZT

if [[ $CONFIGURE_ZT =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Por favor, ingresa el ID de tu red ZeroTier:${NC}"
    read -r ZTNETID
    
    if [ -n "$ZTNETID" ] && [ ${#ZTNETID} -eq 16 ]; then
        sudo zerotier-cli join "$ZTNETID"
        log_success "Raspberry Pi unida a la red ZeroTier: $ZTNETID"
        echo -e "${YELLOW}Recuerda autorizar este dispositivo en tu panel de ZeroTier${NC}"
    else
        log_warning "ID de red ZeroTier inválido (debe tener 16 caracteres)"
    fi
else
    log_info "Configuración de ZeroTier saltada"
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
log_info "🔐 Configurando SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"

if [ -f "$SSHD_CONFIG" ]; then
    backup_file "$SSHD_CONFIG"
    
    sudo sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    sudo sed -i 's/^\s*#\?\s*PubkeyAuthentication.*/PubkeyAuthentication no/' "$SSHD_CONFIG"
    sudo sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    
    grep -q "^PasswordAuthentication" "$SSHD_CONFIG" || echo "PasswordAuthentication yes" | sudo tee -a "$SSHD_CONFIG"
    grep -q "^PubkeyAuthentication" "$SSHD_CONFIG" || echo "PubkeyAuthentication no" | sudo tee -a "$SSHD_CONFIG"
    
    sudo systemctl restart ssh
    log_success "SSH configurado"
fi

# PASO 8: INSTALAR PI_VIDEO_LOOPER EN DIRECTORIO PRINCIPAL
log_info "🎬 Instalando pi_video_looper en /home/admin/VIDLOOP44..."

# Crear directorio principal
sudo mkdir -p /home/admin/VIDLOOP44
sudo chown -R admin:admin /home/admin/VIDLOOP44 2>/dev/null || sudo chown -R admin /home/admin/VIDLOOP44

# Cambiar al directorio principal
cd /home/admin/VIDLOOP44

# Clonar pi_video_looper
log_info "Clonando pi_video_looper de Adafruit..."
if git clone https://github.com/adafruit/pi_video_looper.git; then
    log_success "✅ pi_video_looper clonado exitosamente"
else
    log_error "❌ Error clonando repositorio"
    exit 1
fi

# Configurar permisos
sudo chown -R admin:admin pi_video_looper 2>/dev/null || sudo chown -R admin pi_video_looper

cd pi_video_looper

# Instalar dependencias Python
if [ -f "install.sh" ]; then
    log_info "Ejecutando instalación de pi_video_looper..."
    
    # Crear versión modificada
    cp install.sh install_modified.sh
    sed -i "s/pi:pi/$TARGET_USER:$TARGET_USER/g" install_modified.sh
    sed -i "s/\/home\/pi/\/home\/$TARGET_USER/g" install_modified.sh
    
    chmod +x install_modified.sh
    sudo ./install_modified.sh || {
        log_warning "Instalación original falló, continuando con instalación manual..."
        sudo python3 -m pip install --upgrade pip
        sudo python3 -m pip install -r requirements.txt || log_warning "Algunos paquetes Python fallaron"
    }
fi

cd ..
log_success "pi_video_looper instalado"

# PASO 8.5: CONFIGURAR VIDEO_LOOPER.INI OPTIMIZADO
log_info "⚙️ Creando configuración optimizada de video_looper.ini..."

# Crear directorio de configuración si no existe
sudo mkdir -p /opt/video_looper

# Crear backup del archivo existente si existe
if [ -f "/opt/video_looper/video_looper.ini" ]; then
    backup_file "/opt/video_looper/video_looper.ini"
fi

# Crear video_looper.ini optimizado para anti-micro-cortes
sudo bash -c 'cat > /opt/video_looper/video_looper.ini <<EOF
# VIDLOOP44 - Configuración Personalizada DEFINITIVA
# Desarrollado por IGNACE - Powered By: 44 Contenidos
# OPTIMIZADO PARA ANTI-MICRO-CORTES

[video_looper]
# ===== CONFIGURACIÓN PRINCIPAL =====
# Usar directorio local en lugar de USB
file_reader = directory

# Ruta donde están los videos (directorio principal)
directory_path = /home/admin/VIDLOOP44

# Orden de reproducción: alphabetical, random, reverse
playlist_order = alphabetical

# Repetir playlist infinitamente
repeat = true

# Tiempo de espera entre videos (ULTRA SMOOTH - 50ms)
wait_time = 0.05

# ===== CONFIGURACIÓN DE PANTALLA =====
# Mostrar información en pantalla (false para suavidad)
show_osd = false

# Color de fondo: black para mejor rendimiento
background_color = black

# ===== CONFIGURACIÓN DE VIDEO ANTI-MICRO-CORTES =====
# Argumentos adicionales para omxplayer (OPTIMIZADO)
omxplayer_extra_args = --aspect-mode letterbox --no-osd --audio_queue 20 --video_queue 20 --fps 25 --win 0,0,1920,1080 --genlog --no-keys --timeout 0

# ===== CONFIGURACIÓN DE AUDIO =====
# Habilitar sonido
sound = on

# Volumen (0-100) - Alto para compensar
volume = 90

# ===== CONFIGURACIÓN DEL DIRECTORIO =====
[directory]
# Ruta de los videos (debe coincidir con directory_path)
path = /home/admin/VIDLOOP44

# Extensiones de video soportadas (OPTIMIZADAS)
extensions = mp4,h264,mkv,avi,mov,m4v

# Explorar subdirectorios
subdirectories = false

# ===== CONFIGURACIÓN AVANZADA DE OMXPLAYER =====
[omxplayer]
# Argumentos extra para el reproductor (MÁXIMA OPTIMIZACIÓN)
extra_args = --aspect-mode letterbox --no-osd --vol 900 --audio_queue 20 --video_queue 20 --fps 25 --win 0,0,1920,1080 --genlog --no-keys --timeout 0 --refresh

# ===== CONFIGURACIÓN DE HARDWARE =====
[hardware]
# Usar aceleración de hardware
hw_accel = true

# GPU memory split optimizado
gpu_mem = 256

# ===== OPCIONES ADICIONALES =====
[display]
# Resolución forzada para estabilidad
width = 1920
height = 1080

# Sin rotación para mejor rendimiento
rotation = 0

# ===== CONFIGURACIÓN DE LOGS =====
[logging]
# Nivel de log: INFO para diagnóstico
level = INFO

# Archivo de log
file = /var/log/video_looper.log

# ===== CONFIGURACIÓN AVANZADA ANTI-MICRO-CORTES =====
[performance]
# Buffer preload para evitar cortes
buffer_size = 4096
preload_next = true
smooth_transitions = true

# Process priority para video
video_priority = -20
audio_priority = -20

# ===== NOTAS DE CONFIGURACIÓN =====
#
# RUTAS IMPORTANTES:
# - Videos: /home/admin/VIDLOOP44/
# - Config: /opt/video_looper/video_looper.ini
# - Logs: /var/log/video_looper.log
#
# FORMATOS OPTIMIZADOS ANTI-MICRO-CORTES:
# - Video: MP4 (H.264), H264 puro, MKV (preferidos)
# - Evitar: AVI, WMV, FLV (pueden causar micro-cortes)
#
# PARÁMETROS CLAVE ANTI-MICRO-CORTES:
# - audio_queue=20, video_queue=20 (buffers 20x más grandes)
# - wait_time=0.05 (transición ultra-suave 50ms)
# - fps=25 (frame rate fijo)
# - timeout=0 (sin timeouts que causen cortes)
# - refresh (refresco optimizado)
#
# COMANDOS ÚTILES:
# - Reiniciar servicio: sudo systemctl restart video_looper
# - Ver logs: sudo journalctl -u video_looper -f
# - Verificar config: cat /opt/video_looper/video_looper.ini
# - Diagnóstico: /usr/local/bin/vidloop-definitivo-diagnostic.sh
#
EOF'

# Configurar permisos del archivo de configuración
sudo chown video_looper:video_looper /opt/video_looper/video_looper.ini 2>/dev/null || sudo chown admin:admin /opt/video_looper/video_looper.ini

# Copiar configuración a ubicaciones adicionales donde pi_video_looper la busca
VIDLOOP_CONFIG_LOCATIONS=(
    "/home/admin/VIDLOOP44/pi_video_looper/video_looper.ini"
    "/etc/video_looper.ini"
    "/home/admin/.video_looper.ini"
    "/home/$TARGET_USER/.video_looper.ini"
)

for config_location in "${VIDLOOP_CONFIG_LOCATIONS[@]}"; do
    sudo mkdir -p "$(dirname "$config_location")" 2>/dev/null || true
    sudo cp /opt/video_looper/video_looper.ini "$config_location" 2>/dev/null || true
    sudo chown admin:admin "$config_location" 2>/dev/null || true
    if [ -f "$config_location" ]; then
        log_success "✅ Configuración copiada a: $config_location"
    fi
done

log_success "✅ video_looper.ini optimizado creado y distribuido"

# Reiniciar video_looper si está ejecutándose para aplicar nueva configuración
if systemctl is-active --quiet video_looper; then
    log_info "🔄 Reiniciando video_looper para aplicar nueva configuración..."
    sudo systemctl restart video_looper
    sleep 3
fi

# Verificar que la configuración se aplicó correctamente
if [ -f "/opt/video_looper/video_looper.ini" ]; then
    log_success "✅ Configuración anti-micro-cortes aplicada correctamente"
    log_info "📋 Configuración clave:"
    log_info "   • Buffers: audio_queue=20, video_queue=20"
    log_info "   • Transición: wait_time=0.05s (ultra-suave)"
    log_info "   • GPU Memory: 256MB para hardware acceleration"
    log_info "   • Formatos recomendados: MP4, H264, MKV"
else
    log_warning "⚠️ No se pudo verificar la configuración"
fi

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
while true; do
    if command -v tvservice >/dev/null 2>&1; then
        if tvservice -s 2>/dev/null | grep -q "TV is off"; then
            tvservice -p 2>/dev/null || true
            chvt 6 && chvt 7 2>/dev/null || true
        elif ! tvservice -s 2>/dev/null | grep -q "0x12000"; then
            tvservice -p 2>/dev/null || true
            chvt 6 && chvt 7 2>/dev/null || true
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
    log_success "Servicio HDMI keepalive configurado"
fi

# PASO 11: CREAR CARPETA DE VIDEOS
VIDEOS_DIR="/home/admin/VIDLOOP44"
log_info "📁 Configurando carpeta de videos: $VIDEOS_DIR"
sudo mkdir -p "$VIDEOS_DIR"
sudo chown -R admin:admin "$VIDEOS_DIR" 2>/dev/null || sudo chown -R admin "$VIDEOS_DIR"
log_success "Carpeta de videos creada: $VIDEOS_DIR"

# PASO 12: CREAR SCRIPT DEFINITIVO ANTI-MICRO-CORTES
log_info "🎬 Creando script DEFINITIVO ANTI-MICRO-CORTES..."

DEFINITIVO_SCRIPT="/usr/local/bin/vidloop-definitivo.sh"
sudo bash -c "cat > $DEFINITIVO_SCRIPT <<'DEFINITIVO_EOF'
#!/bin/bash
# VIDLOOP DEFINITIVO - Script ANTI-MICRO-CORTES
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

log_msg \"INFO\" \"🚀 Iniciando VIDLOOP DEFINITIVO...\"

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
    log_msg \"ERROR\" \"❌ Carpeta no existe: \$VIDEOS_DIR\"
    exit 1
fi

# Buscar videos (formatos optimizados para anti-micro-cortes)
VIDEO_FILES=\$(find \"\$VIDEOS_DIR\" -type f \\( -iname \"*.mp4\" -o -iname \"*.h264\" -o -iname \"*.mkv\" \\) 2>/dev/null | sort)

if [ -z \"\$VIDEO_FILES\" ]; then
    log_msg \"ERROR\" \"❌ NO HAY VIDEOS optimizados en \$VIDEOS_DIR\"
    log_msg \"INFO\" \"Formatos recomendados: .mp4, .h264, .mkv\"
    exit 1
fi

VIDEO_COUNT=\$(echo \"\$VIDEO_FILES\" | wc -l)
log_msg \"INFO\" \"✅ Encontrados \$VIDEO_COUNT videos optimizados\"

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
        --vol 1000 \\
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
        omxplayer --display 7 --aspect-mode letterbox --no-osd --vol 1000 \"\$video\" 2>/dev/null || {
            log_msg \"ERROR\" \"Error fatal con \$name\"
            return 1
        }
    }
    
    return 0
}

# MÉTODO 1: INTENTAR PI_VIDEO_LOOPER OPTIMIZADO
MAIN_VIDLOOP_DIR=\"/home/admin/VIDLOOP44/pi_video_looper\"

if [ -f \"\$MAIN_VIDLOOP_DIR/video_looper.py\" ]; then
    log_msg \"INFO\" \"🎬 INTENTANDO PI_VIDEO_LOOPER OPTIMIZADO\"
    cd \"\$MAIN_VIDLOOP_DIR\"
    
    # Crear configuración DEFINITIVA ANTI-MICRO-CORTES
    CONFIG_FILE=\"\$MAIN_VIDLOOP_DIR/video_looper_definitivo.ini\"
    cat > \"\$CONFIG_FILE\" <<CONFIG_EOF
[video_looper]
file_reader = directory
directory_path = \$VIDEOS_DIR
playlist_order = alphabetical
repeat = true
wait_time = 0
show_osd = false
background_color = black
sound = on
volume = 100

[directory]
path = \$VIDEOS_DIR
extensions = mp4,h264,mkv
subdirectories = false

[omxplayer]
extra_args = --display 7 --aspect-mode letterbox --no-osd --vol 1000 --refresh --layer 1 --alpha 255 --advanced --hw --boost-on-downmix --audio_queue 20 --video_queue 20 --audio_fifo 20 --video_fifo 20 --threshold 0.5 --fps 30

[usb_drive]
enabled = false

[usb]
enabled = false
CONFIG_EOF
    
    log_msg \"INFO\" \"🚀 Ejecutando pi_video_looper DEFINITIVO\"
    timeout 60 python3 video_looper.py --config \"\$CONFIG_FILE\" 2>&1 &
    VIDLOOP_PID=\$!
    
    # Esperar para verificar si funciona
    sleep 30
    
    if kill -0 \$VIDLOOP_PID 2>/dev/null; then
        log_msg \"SUCCESS\" \"✅ pi_video_looper DEFINITIVO ejecutándose SUAVE\"
        wait \$VIDLOOP_PID
    else
        log_msg \"WARNING\" \"⚠️ pi_video_looper falló, usando reproducción directa OPTIMIZADA\"
    fi
fi

# MÉTODO 2: REPRODUCCIÓN DIRECTA ANTI-MICRO-CORTES
log_msg \"INFO\" \"🎬 REPRODUCCIÓN DIRECTA ANTI-MICRO-CORTES\"

# Precargar archivos en cache
log_msg \"INFO\" \"Precargando archivos...\"
echo \"\$VIDEO_FILES\" | while read -r video; do
    if command -v vmtouch >/dev/null 2>&1; then
        vmtouch -t \"\$video\" >/dev/null 2>&1 &
    fi
done

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
    sleep 0.5
done
DEFINITIVO_EOF"

sudo chmod +x "$DEFINITIVO_SCRIPT"
log_success "✅ Script DEFINITIVO ANTI-MICRO-CORTES creado"

# PASO 13: CREAR SERVICIO DEFINITIVO
log_info "⚙️ Creando servicio systemd DEFINITIVO..."

sudo bash -c "cat > /etc/systemd/system/vidloop-definitivo.service <<EOF
[Unit]
Description=VIDLOOP DEFINITIVO - Anti-Micro-Cortes Video Player
After=multi-user.target graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=root
Group=root
Environment=HOME=/home/admin
Environment=USER=admin
Environment=DISPLAY=:0.0
Environment=OMX_BUFFERS=512
Environment=OMX_MAX_FPS=60
Environment=FRAMEBUFFER=/dev/fb0
WorkingDirectory=/home/admin
ExecStartPre=/bin/sleep 40
ExecStart=$DEFINITIVO_SCRIPT
Restart=always
RestartSec=3
TimeoutStartSec=300
StandardOutput=append:/var/log/vidloop-definitivo.log
StandardError=append:/var/log/vidloop-definitivo.log
Nice=-20
IOSchedulingClass=1
IOSchedulingPriority=0
CPUSchedulingPolicy=1
CPUSchedulingPriority=99

[Install]
WantedBy=multi-user.target
EOF"

# PASO 14: DESHABILITAR SERVICIOS ANTERIORES Y HABILITAR DEFINITIVO
log_info "🔄 Configurando servicio DEFINITIVO..."
sudo systemctl stop vidloop-player.service 2>/dev/null || true
sudo systemctl disable vidloop-player.service 2>/dev/null || true
sudo systemctl stop vidloop-ultra.service 2>/dev/null || true
sudo systemctl disable vidloop-ultra.service 2>/dev/null || true
sudo systemctl stop vidloop-smooth.service 2>/dev/null || true
sudo systemctl disable vidloop-smooth.service 2>/dev/null || true

sudo systemctl daemon-reload
sudo systemctl enable vidloop-definitivo.service

log_success "✅ Servicio DEFINITIVO configurado"

# PASO 15: CONFIGURAR RC.LOCAL COMO RESPALDO
log_info "📋 Configurando rc.local de respaldo..."
RC_LOCAL="/etc/rc.local"
backup_file "$RC_LOCAL" 2>/dev/null || true

sudo bash -c "cat > $RC_LOCAL <<EOF
#!/bin/sh -e
# VIDLOOP DEFINITIVO - RC.LOCAL RESPALDO

# Forzar display y ejecutar respaldo
(
    sleep 70
    if command -v tvservice >/dev/null 2>&1; then
        tvservice -p 2>/dev/null || true
        sleep 3
        tvservice --explicit=\"CEA 16 HDMI\" 2>/dev/null || true
    fi
    
    # Si el servicio no está corriendo, ejecutar manualmente
    if ! systemctl is-active --quiet vidloop-definitivo.service; then
        su - root -c '$DEFINITIVO_SCRIPT' &
    fi
) &

exit 0
EOF"

sudo chmod +x "$RC_LOCAL"

# PASO 16: CONFIGURAR LOGS
sudo touch /var/log/vidloop-definitivo.log
sudo chmod 666 /var/log/vidloop-definitivo.log

# PASO 17: CREAR SCRIPT DE DIAGNÓSTICO DEFINITIVO
DIAG_DEFINITIVO="/usr/local/bin/vidloop-definitivo-diagnostic.sh"
sudo bash -c "cat > $DIAG_DEFINITIVO <<'DIAG_EOF'
#!/bin/bash

echo \"========================================\"
echo \"   DIAGNÓSTICO VIDLOOP DEFINITIVO - \$(date)\"
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

# 3. Videos optimizados
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
            size=\$(du -h \"\$video\" 2>/dev/null | cut -f1)
            echo \"    ✅ \$(basename \"\$video\") (\$size)\"
        done
    else
        echo \"  ❌ NO HAY VIDEOS OPTIMIZADOS\"
        echo \"  💡 Formatos recomendados: .mp4, .h264, .mkv\"
    fi
else
    echo \"  ❌ Carpeta no existe\"
fi

echo \"\"

# 4. Servicio DEFINITIVO
echo \"⚙️ SERVICIO DEFINITIVO:\"
if systemctl is-active --quiet vidloop-definitivo.service; then
    echo \"  ✅ Servicio ACTIVO\"
else
    echo \"  ❌ Servicio INACTIVO\"
fi

if systemctl is-enabled --quiet vidloop-definitivo.service; then
    echo \"  ✅ Servicio HABILITADO\"
else
    echo \"  ❌ Servicio NO habilitado\"
fi

echo \"\"

# 5. Procesos optimizados
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

if pgrep -f omxplayer >/dev/null; then
    echo \"  ✅ omxplayer ejecutándose\"
    omx_count=\$(pgrep -f omxplayer | wc -l)
    echo \"    Instancias: \$omx_count\"
else
    echo \"  ❌ omxplayer NO ejecutándose\"
fi

echo \"\"

# 6. Logs DEFINITIVOS
echo \"📝 LOGS DEFINITIVOS (últimas 15 líneas):\"
if [ -f \"/var/log/vidloop-definitivo.log\" ]; then
    tail -15 /var/log/vidloop-definitivo.log | sed 's/^/  /'
else
    echo \"  ❌ No se encontró log definitivo\"
fi

echo \"\"
echo \"========================================\"
echo \"🛠️  COMANDOS DEFINITIVOS:\"
echo \"  • Ver logs: tail -f /var/log/vidloop-definitivo.log\"
echo \"  • Reiniciar: sudo systemctl restart vidloop-definitivo\"
echo \"  • Estado: sudo systemctl status vidloop-definitivo\"
echo \"  • Ejecutar manual: sudo $DEFINITIVO_SCRIPT\"
echo \"  • Diagnóstico: sudo $DIAG_DEFINITIVO\"
echo \"  • Temperatura: vcgencmd measure_temp\"
echo \"  • HDMI estado: tvservice -s\"
echo \"========================================\"
DIAG_EOF"

sudo chmod +x "$DIAG_DEFINITIVO"
log_success "✅ Diagnóstico DEFINITIVO creado"

# RESUMEN FINAL
echo
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}           VIDLOOP DEFINITIVO CONFIGURADO EXITOSAMENTE         ${NC}"
echo -e "${GREEN}================================================================${NC}"

echo -e "${YELLOW}✨ CARACTERÍSTICAS DEFINITIVAS:${NC}"
echo "  • ✅ GPU optimizada: 256MB + overclock suave"
echo "  • ✅ HDMI ultra agresivo con force display"
echo "  • ✅ Buffers maximizados: 20x audio/video queues"
echo "  • ✅ Prioridad máxima: Nice -20, IO Class 1"
echo "  • ✅ CPU Governor: Performance mode"
echo "  • ✅ Parámetros anti-micro-cortes definitivos"
echo "  • ✅ Formatos optimizados: MP4, H264, MKV"
echo "  • ✅ Precarga de archivos en memoria"
echo "  • ✅ Transiciones ultra suaves (0.05s)"

echo
echo -e "${BLUE}📋 INFORMACIÓN DEL SISTEMA:${NC}"
echo -e "${BLUE}👤 Usuario SSH:${NC} admin"
echo -e "${BLUE}🔑 Contraseña SSH:${NC} 4455"
echo -e "${BLUE}📁 Carpeta de videos:${NC} /home/admin/VIDLOOP44"
echo -e "${BLUE}🎬 Servicio:${NC} vidloop-definitivo.service"
echo -e "${BLUE}📝 Logs:${NC} /var/log/vidloop-definitivo.log"

if [ "$IS_RPI" = true ]; then
    echo -e "${BLUE}📺 HDMI:${NC} Ultra agresivo + keepalive"
fi

if command_exists zerotier-cli; then
    ZT_STATUS=$(sudo zerotier-cli info 2>/dev/null | cut -d' ' -f3 || echo "No configurado")
    echo -e "${BLUE}🌐 ZeroTier:${NC} Instalado (Estado: $ZT_STATUS)"
fi

echo
echo -e "${YELLOW}🚀 PRÓXIMOS PASOS:${NC}"
echo "  1. 📥 Copia videos OPTIMIZADOS (MP4/H264/MKV) a: /home/admin/VIDLOOP44"
echo "  2. 🌐 Si configuraste ZeroTier, autoriza el dispositivo"
echo "  3. 🔄 REINICIA el sistema: sudo reboot"
echo "  4. 🕐 Espera 1-2 minutos después del reinicio"
echo "  5. 🎬 Los videos se reproducirán SIN micro cortes"

echo
echo -e "${YELLOW}🛠️  COMANDOS ESENCIALES:${NC}"
echo "  • 🔍 DIAGNÓSTICO COMPLETO: sudo $DIAG_DEFINITIVO"
echo "  • 📝 Ver logs: tail -f /var/log/vidloop-definitivo.log"
echo "  • 🔄 Reiniciar servicio: sudo systemctl restart vidloop-definitivo"
echo "  • ⚙️ Estado servicio: sudo systemctl status vidloop-definitivo"
echo "  • 🎬 Ejecutar manual: sudo $DEFINITIVO_SCRIPT"
echo "  • 📁 Agregar video: cp video.mp4 /home/admin/VIDLOOP44/"

echo
echo -e "${CYAN}🎯 SOLUCIÓN DE PROBLEMAS:${NC}"
echo "  • 🖥️ PANTALLA NEGRA:"
echo "    1. sudo $DIAG_DEFINITIVO"
echo "    2. Verificar videos en /home/admin/VIDLOOP44"
echo "    3. tail -f /var/log/vidloop-definitivo.log"
echo "    4. sudo systemctl restart vidloop-definitivo"
echo
echo "  • 🔄 MICRO CORTES PERSISTEN:"
echo "    1. Verificar temperatura: vcgencmd measure_temp"
echo "    2. Usar solo formatos MP4, H264, MKV"
echo "    3. Verificar que GPU tenga 256MB"
echo "    4. Reducir resolución de videos si necesario"

echo
echo -e "${RED}⚠️  IMPORTANTE:${NC}"
echo "  • Se aplicó overclock suave - monitorea temperatura"
echo "  • Formatos recomendados: MP4 (H264), H264 puro, MKV"
echo "  • Evita AVI, WMV, FLV (causan micro cortes)"
echo "  • Videos de alta resolución pueden causar cortes"

echo
echo -e "${GREEN}🎯 Desarrollado por IGNACE - Powered By: 44 Contenidos${NC}"
echo -e "${GREEN}   ✨ VERSIÓN DEFINITIVA ANTI-MICRO-CORTES ✨${NC}"

# Preguntar si reiniciar
echo
echo -e "${YELLOW}¿Deseas reiniciar el sistema ahora para aplicar todos los cambios? (y/n):${NC}"
read -r REBOOT_NOW

if [[ $REBOOT_NOW =~ ^[Yy]$ ]]; then
    log_info "🔄 Reiniciando sistema en 10 segundos..."
    echo "Después del reinicio:"
    echo "  ✨ El sistema estará optimizado al máximo"
    echo "  🎬 Los videos se reproducirán sin micro cortes"
    echo "  🔍 Si hay problemas, usa el diagnóstico"
    echo "  🌐 Conecta por SSH si necesitas acceso remoto"
    
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
    echo "El sistema DEFINITIVO está configurado pero necesita reiniciar para funcionar al máximo"
fi

log_success "🎯 VIDLOOP DEFINITIVO ANTI-MICRO-CORTES COMPLETADO"