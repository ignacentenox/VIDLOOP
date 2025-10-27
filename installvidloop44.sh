#!/bin/bash
set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging con colores
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Banner
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    VIDLOOP SETUP - RASPBERRY PI INSTALLER    ${NC}"
echo -e "${BLUE}   Desarrollado por IGNACE - Powered By: 44    ${NC}"
echo -e "${BLUE}================================================${NC}"

# Detectar usuario actual y sistema
CURRENT_USER=$(whoami)
SUDO_USER_DETECTED=${SUDO_USER:-$CURRENT_USER}
HOME_DIR="/home/$SUDO_USER_DETECTED"

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
        sudo cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backup creado: ${file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Actualizar sistema
log_info "Actualizando sistema..."
sudo apt-get update -y
sudo apt-get upgrade -y
log_success "Sistema actualizado"

# Instalar dependencias básicas
log_info "Instalando dependencias básicas..."
sudo apt-get install -y \
    git \
    python3 \
    python3-pip \
    ffmpeg \
    curl \
    wget \
    build-essential \
    python3-dev \
    || { log_error "Error instalando dependencias básicas"; exit 1; }
log_success "Dependencias básicas instaladas"

# Configurar HDMI solo en Raspberry Pi
if [ "$IS_RPI" = true ]; then
    log_info "Configurando salida HDMI..."
    CONFIG_FILE="/boot/config.txt"
    
    # Verificar si existe el archivo de configuración (puede estar en /boot/firmware/ en sistemas más nuevos)
    if [ ! -f "$CONFIG_FILE" ] && [ -f "/boot/firmware/config.txt" ]; then
        CONFIG_FILE="/boot/firmware/config.txt"
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        backup_file "$CONFIG_FILE"
        
        # Remover configuraciones HDMI existentes para evitar duplicados
        sudo sed -i '/^hdmi_force_hotplug=/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^hdmi_drive=/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^hdmi_group=/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^hdmi_mode=/d' "$CONFIG_FILE" 2>/dev/null || true
        sudo sed -i '/^config_hdmi_boost=/d' "$CONFIG_FILE" 2>/dev/null || true
        
        # Agregar configuración HDMI
        sudo bash -c "cat >> $CONFIG_FILE <<EOF

# ---- VIDLOOP HDMI CONFIGURATION ----
hdmi_force_hotplug=1
hdmi_drive=2
hdmi_group=1
hdmi_mode=16
config_hdmi_boost=7
EOF"
        log_success "Configuración HDMI aplicada"
    else
        log_warning "Archivo config.txt no encontrado, saltando configuración HDMI"
    fi
fi

# Dar permisos de ejecución a scripts en el directorio actual
log_info "Configurando permisos de scripts..."
find . -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true
log_success "Permisos configurados"

# Clonar e instalar pi_video_looper
log_info "Clonando pi_video_looper de Adafruit..."
if [ -d "pi_video_looper" ]; then
    log_warning "Directorio pi_video_looper ya existe, eliminando..."
    rm -rf pi_video_looper
fi

git clone https://github.com/adafruit/pi_video_looper.git || {
    log_error "Error clonando repositorio pi_video_looper"
    exit 1
}

cd pi_video_looper

# Modificar el script de instalación para usar el usuario correcto
if [ -f "install.sh" ]; then
    log_info "Modificando script de instalación para usuario: $TARGET_USER"
    
    # Crear una versión modificada del script de instalación
    cp install.sh install_modified.sh
    
    # Reemplazar referencias al usuario 'pi' con el usuario actual
    sed -i "s/pi:pi/$TARGET_USER:$TARGET_USER/g" install_modified.sh
    sed -i "s/\/home\/pi/\/home\/$TARGET_USER/g" install_modified.sh
    
    # Hacer ejecutable y ejecutar
    chmod +x install_modified.sh
    sudo ./install_modified.sh || {
        log_warning "Error en instalación original, continuando con instalación manual..."
        
        # Instalación manual básica
        log_info "Realizando instalación manual..."
        sudo python3 -m pip install --upgrade pip
        sudo python3 -m pip install -r requirements.txt || log_warning "Algunos paquetes Python pueden haber fallado"
        
        # Crear directorio de configuración
        sudo mkdir -p /opt/video_looper
        sudo cp -r . /opt/video_looper/
        sudo chown -R "$TARGET_USER:$TARGET_USER" /opt/video_looper/ 2>/dev/null || {
            # Si el grupo no existe, usar solo el usuario
            sudo chown -R "$TARGET_USER" /opt/video_looper/
        }
    }
else
    log_error "Script install.sh no encontrado"
    exit 1
fi

cd ..
log_success "pi_video_looper instalado"

# Configurar video_looper.ini personalizado si existe
if [ -f "./video_looper.ini" ]; then
    log_info "Configurando video_looper.ini personalizado..."
    sudo cp ./video_looper.ini ./pi_video_looper/assets/video_looper.ini
    log_success "Configuración personalizada aplicada"
else
    log_warning "Archivo video_looper.ini no encontrado, usando configuración por defecto"
fi

# Instalar ZeroTier para VPN
log_info "Instalando ZeroTier para VPN..."
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
        echo "Puedes unir manualmente luego con: sudo zerotier-cli join <ID>"
    fi
else
    log_info "Configuración de ZeroTier saltada. Puedes configurar luego con: sudo zerotier-cli join <ID>"
fi

# Crear/configurar usuario admin
log_info "Configurando usuario admin..."
if id -u admin >/dev/null 2>&1; then
    log_info "Usuario 'admin' existe. Actualizando contraseña..."
else
    log_info "Creando usuario 'admin'..."
    sudo adduser --disabled-password --gecos "" admin
    sudo usermod -aG sudo admin  # Agregar al grupo sudo
fi

echo "admin:4455" | sudo chpasswd
log_success "Usuario admin configurado con contraseña: 4455"

# Configurar SSH para permitir autenticación por contraseña
log_info "Configurando SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"

if [ -f "$SSHD_CONFIG" ]; then
    backup_file "$SSHD_CONFIG"
    
    # Configurar SSH
    sudo sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    sudo sed -i 's/^\s*#\?\s*PubkeyAuthentication.*/PubkeyAuthentication no/' "$SSHD_CONFIG"
    sudo sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    
    # Asegurar que las configuraciones estén presentes
    grep -q "^PasswordAuthentication" "$SSHD_CONFIG" || echo "PasswordAuthentication yes" | sudo tee -a "$SSHD_CONFIG"
    grep -q "^PubkeyAuthentication" "$SSHD_CONFIG" || echo "PubkeyAuthentication no" | sudo tee -a "$SSHD_CONFIG"
    
    # Reiniciar SSH
    sudo systemctl restart ssh
    log_success "SSH configurado (solo autenticación por contraseña)"
else
    log_warning "Archivo sshd_config no encontrado"
fi

# Evitar screen blanking solo en Raspberry Pi
if [ "$IS_RPI" = true ]; then
    log_info "Configurando prevención de screen blanking..."
    
    AUTOSTART_DIRS=(
        "/etc/xdg/lxsession/LXDE-pi/autostart"
        "/etc/xdg/lxsession/LXDE/autostart"
        "/home/$TARGET_USER/.config/lxsession/LXDE-pi/autostart"
    )
    
    for AUTOSTART in "${AUTOSTART_DIRS[@]}"; do
        if [ -f "$AUTOSTART" ]; then
            backup_file "$AUTOSTART"
            
            # Remover líneas existentes
            sudo sed -i '/xset s off/d' "$AUTOSTART" 2>/dev/null || true
            sudo sed -i '/xset -dpms/d' "$AUTOSTART" 2>/dev/null || true
            sudo sed -i '/xset s noblank/d' "$AUTOSTART" 2>/dev/null || true
            
            # Agregar configuración
            sudo bash -c "cat >> $AUTOSTART <<EOF
@xset s off
@xset -dpms
@xset s noblank
EOF"
            log_success "Screen blanking deshabilitado en $AUTOSTART"
            break
        fi
    done
fi

# Instalar tvservice solo en Raspberry Pi
if [ "$IS_RPI" = true ]; then
    log_info "Verificando tvservice..."
    if ! command_exists tvservice; then
        sudo apt-get update
        sudo apt-get install -y libraspberrypi-bin || log_warning "No se pudo instalar libraspberrypi-bin"
    fi
    
    # Crear script hdmi-keepalive
    log_info "Creando servicio HDMI keepalive..."
    sudo bash -c 'cat > /usr/local/bin/hdmi-keepalive.sh <<EOF
#!/bin/bash
# HDMI Keepalive service for VIDLOOP
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
    
    # Crear servicio systemd
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

# Crear carpeta de videos
log_info "Creando carpeta de videos..."
VIDEOS_DIR="$TARGET_HOME/VIDLOOP44"
sudo mkdir -p "$VIDEOS_DIR"

# Configurar permisos correctamente
if id -u "$TARGET_USER" >/dev/null 2>&1; then
    if getent group "$TARGET_USER" >/dev/null 2>&1; then
        sudo chown -R "$TARGET_USER:$TARGET_USER" "$VIDEOS_DIR"
    else
        sudo chown -R "$TARGET_USER" "$VIDEOS_DIR"
    fi
    log_success "Carpeta de videos creada: $VIDEOS_DIR"
else
    log_warning "No se pudieron configurar permisos para $VIDEOS_DIR"
fi

# Resumen final
echo
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}           INSTALACIÓN COMPLETADA              ${NC}"
echo -e "${GREEN}================================================${NC}"
echo -e "${BLUE}Usuario SSH:${NC} admin"
echo -e "${BLUE}Contraseña SSH:${NC} 4455"
echo -e "${BLUE}Carpeta de videos:${NC} $VIDEOS_DIR"
echo -e "${BLUE}Usuario propietario:${NC} $TARGET_USER"

if [ "$IS_RPI" = true ]; then
    echo -e "${BLUE}HDMI:${NC} Forzado y servicio keepalive activo"
fi

if command_exists zerotier-cli; then
    ZT_STATUS=$(sudo zerotier-cli info 2>/dev/null | cut -d' ' -f3 || echo "No configurado")
    echo -e "${BLUE}ZeroTier:${NC} Instalado (Estado: $ZT_STATUS)"
fi

echo
echo -e "${YELLOW}PRÓXIMOS PASOS:${NC}"
echo "1. Coloca tus videos en: $VIDEOS_DIR"
echo "2. Si configuraste ZeroTier, autoriza el dispositivo en tu panel"
echo "3. Reinicia el sistema para aplicar todos los cambios"
echo
echo -e "${GREEN}Desarrollado por IGNACE - Powered By: 44 Contenidos${NC}"
echo

# Preguntar si reiniciar
echo -e "${YELLOW}¿Deseas reiniciar el sistema ahora? (y/n):${NC}"
read -r REBOOT_NOW

if [[ $REBOOT_NOW =~ ^[Yy]$ ]]; then
    log_info "Reiniciando sistema en 5 segundos..."
    sleep 5
    sudo reboot
else
    log_info "Recuerda reiniciar el sistema manualmente para aplicar todos los cambios"
fi
