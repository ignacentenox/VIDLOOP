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

VIDLOOP_NONINTERACTIVE="${VIDLOOP_NONINTERACTIVE:-true}"
VIDLOOP_AUTO_REBOOT="${VIDLOOP_AUTO_REBOOT:-true}"
VIDLOOP_ENABLE_MEDIA_NORMALIZER="${VIDLOOP_ENABLE_MEDIA_NORMALIZER:-true}"
VIDLOOP_IMAGE_DURATION_SEC="${VIDLOOP_IMAGE_DURATION_SEC:-20}"
VIDLOOP_IMAGE_SCAN_INTERVAL_MIN="${VIDLOOP_IMAGE_SCAN_INTERVAL_MIN:-1}"
VIDLOOP_SYSTEM_USER="vidloop"
VIDLOOP_SYSTEM_PASS="4455"

# Evita prompts interactivos en TODO el script desde el inicio
export DEBIAN_FRONTEND=noninteractive

is_true() {
    case "${1:-}" in
        1|true|TRUE|yes|YES|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

generate_password() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 18 | tr -d '\n' | tr '/+' 'XY' | cut -c1-20
        return
    fi
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Falta el comando requerido: $1"
        exit 1
    fi
}

ensure_cmd_or_install() {
    # Instala un paquete si el comando no existe
    local cmd="$1"
    local pkg="${2:-$1}"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    log_info "Instalando $pkg para obtener comando $cmd..."
    sudo apt-get install -y "$pkg" || {
        log_error "No se pudo instalar $pkg"
        return 1
    }
}

ensure_legacy_raspbian_repo_if_needed() {
    # En Buster, los repos de raspbian.org y archive.debian.org tienen GPG vencidos.
    # No se agrega ningún source sin [trusted=yes]: eso provoca el error de GPG.
    # En su lugar, configure_buster_archive_sources_trusted se llama proactivamente.
    if ! command -v lsb_release >/dev/null 2>&1; then
        return
    fi

    local codename
    codename="$(lsb_release -sc 2>/dev/null || true)"
    if [ "$codename" != "buster" ]; then
        return
    fi

    # Aplicar fixes de confianza ANTES del primer apt update para evitar ciclos de error.
    configure_buster_archive_sources_trusted
}

configure_buster_archive_sources_trusted() {
    # En Buster legacy, los GPG keys de archive.debian.org y raspbian.org están vencidos.
    # Solución: comentar todas las fuentes problemáticas y usar trusted=yes.
    # Idempotente: no hace nada si ya está aplicado.
    if ! command -v lsb_release >/dev/null 2>&1; then
        return
    fi

    local codename
    codename="$(lsb_release -sc 2>/dev/null || true)"
    if [ "$codename" != "buster" ]; then
        return
    fi

    # Evitar doble aplicación
    if [ -f /etc/apt/sources.list.d/vidloop-buster-archive.list ]; then
        return
    fi

    log_warn "Aplicando fuentes APT confiables para Buster (trusted=yes)..."

    if [ -f /etc/apt/sources.list ]; then
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%s)
        # Comentar archive.debian.org (GPG expirado)
        sudo sed -i 's|^deb \(.*archive\.debian\.org.*\)|# \1|g' /etc/apt/sources.list
        sudo sed -i 's|^deb-src \(.*archive\.debian\.org.*\)|# \1|g' /etc/apt/sources.list
        # Comentar raspbian.org y raspberrypi.org (GPG expirado en Buster old)
        sudo sed -i 's|^deb \(.*raspbian\.org.*\)|# \1|g' /etc/apt/sources.list
        sudo sed -i 's|^deb-src \(.*raspbian\.org.*\)|# \1|g' /etc/apt/sources.list
        sudo sed -i 's|^deb \(.*raspberrypi\.org.*\)|# \1|g' /etc/apt/sources.list
        sudo sed -i 's|^deb-src \(.*raspberrypi\.org.*\)|# \1|g' /etc/apt/sources.list
    fi

    # También limpiar cualquier source.list.d que pueda tener los repos problemáticos
    for f in /etc/apt/sources.list.d/*.list; do
        [ -f "$f" ] || continue
        [[ "$f" == *"vidloop"* ]] && continue
        sudo sed -i 's|^deb \(.*archive\.debian\.org.*\)|# \1|g' "$f" 2>/dev/null || true
        sudo sed -i 's|^deb \(.*raspbian\.org.*\)|# \1|g' "$f" 2>/dev/null || true
        sudo sed -i 's|^deb \(.*raspberrypi\.org.*\)|# \1|g' "$f" 2>/dev/null || true
    done

    sudo tee /etc/apt/sources.list.d/vidloop-buster-archive.list >/dev/null <<'EOF'
deb [trusted=yes] http://archive.debian.org/debian buster main contrib non-free
deb [trusted=yes] http://archive.debian.org/debian buster-backports main
deb [trusted=yes] http://archive.raspberrypi.org/debian/ buster main
deb [trusted=yes] http://raspbian.raspberrypi.org/raspbian/ buster main contrib non-free rpi
EOF

    sudo mkdir -p /etc/apt/apt.conf.d
    echo 'APT::Get::AllowUnauthenticated "true";' | sudo tee /etc/apt/apt.conf.d/99-vidloop-unauthenticated >/dev/null
}

upsert_kv() {
    # Reemplaza o agrega una clave de config de forma ESTRICTAMENTE idempotente.
    local file="$1"
    local key="$2"
    local value="$3"
    sudo touch "$file"
    # Primero eliminar TODAS las líneas que matcheen el key (comentadas o no)
    sudo sed -i "/^[[:space:]]*#*[[:space:]]*${key}=/d" "$file"
    # Luego agregar EXACTAMENTE UNA línea con el nuevo valor
    echo "${key}=${value}" | sudo tee -a "$file" >/dev/null
}

append_once() {
    local file="$1"
    local line="$2"
    sudo touch "$file"
    if ! sudo grep -Fxq "$line" "$file"; then
        echo "$line" | sudo tee -a "$file" >/dev/null
    fi
}

user_has_authorized_keys() {
    local user_name="$1"
    local user_home
    user_home="$(eval echo "~${user_name}")"
    local auth_file="${user_home}/.ssh/authorized_keys"

    if [ -s "$auth_file" ]; then
        return 0
    fi
    return 1
}

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}               VIDLOOP V3.0                    ${NC}"
echo -e "${BLUE}        Setup seguro + idempotente             ${NC}"
echo -e "${BLUE}================================================${NC}"

require_cmd sudo
require_cmd awk
require_cmd sed
require_cmd tr
require_cmd head

# Validar que sudo funciona sin password (necesario para el script)
if ! sudo -n true 2>/dev/null; then
    log_error "sudo sin password es requerido. Configura en /etc/sudoers: $SUDO_USER ALL=(ALL) NOPASSWD:ALL"
    exit 1
fi
log_ok "Permisos de sudo validados"

WG_INTERFACE="${VIDLOOP_WG_INTERFACE:-wg0}"

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

ensure_legacy_raspbian_repo_if_needed

log_info "Actualizando paquetes..."
APT_ATTEMPT=1
while [ $APT_ATTEMPT -le 3 ]; do
    if sudo apt-get update -o Acquire::Check-Valid-Until=false 2>&1; then
        log_ok "apt-get update exitoso en intento $APT_ATTEMPT"
        break
    else
        log_warn "Intento $APT_ATTEMPT de apt-get update falló, aplicando fallback..."
        
        if [ $APT_ATTEMPT -eq 1 ]; then
            configure_buster_archive_sources_trusted
        elif [ $APT_ATTEMPT -eq 2 ]; then
            log_warn "Habilitando paquetes no autenticados..."
            sudo mkdir -p /etc/apt/apt.conf.d
            echo 'APT::Get::AllowUnauthenticated "true";' | sudo tee /etc/apt/apt.conf.d/99-vidloop-unauthenticated >/dev/null
        fi
        
        if [ $APT_ATTEMPT -eq 3 ]; then
            log_error "apt-get update falló después de 3 intentos. Verifica la conexión a internet."
            exit 1
        fi
        
        sleep 2
        APT_ATTEMPT=$((APT_ATTEMPT + 1))
    fi
done

# Detectar y reparar dependencias rotas antes de full-upgrade
log_info "Verificando integridad de dependencias..."
if ! sudo apt-get check 2>/dev/null; then
    log_warn "Se detectaron dependencias rotas, intentando reparar..."
    if sudo apt-get install -f -y 2>/dev/null; then
        log_ok "Dependencias reparadas con 'apt install -f'"
    elif sudo apt --fix-broken install -y 2>/dev/null; then
        log_ok "Dependencias reparadas con 'apt --fix-broken install'"
    else
        log_warn "No se pudieron reparar las dependencias automáticamente"
        log_warn "Continuando con instalación, pero algunos paquetes pueden no instalarse"
    fi
else
    log_ok "Sistema de paquetes íntegro"
fi

if is_true "${VIDLOOP_FULL_UPGRADE:-true}"; then
    log_info "Aplicando full-upgrade (puede tardar)..."
    if sudo apt-get full-upgrade -y 2>&1; then
        log_ok "full-upgrade completado"
    else
        log_warn "full-upgrade falló, continuando con instalación base"
    fi
else
    log_warn "VIDLOOP_FULL_UPGRADE=false: se omite full-upgrade"
fi
log_ok "Índice de paquetes actualizado"

log_info "Instalando dependencias base..."
sudo apt-get install -y \
    htop \
    iotop \
    curl \
    wget \
    git \
    unzip \
    ca-certificates \
    ffmpeg \
    python3 \
    python3-pip \
    openssh-server \
    || { log_error "Fallo la instalacion de dependencias"; exit 1; }
log_ok "Dependencias base instaladas"

# ================================================================
# Configurar idioma Español Argentina y zona horaria
# ================================================================
log_info "Configurando idioma Español Argentina (es_AR.UTF-8)..."
if [ -f /etc/locale.gen ]; then
    # Habilitar locale es_AR.UTF-8 si no está activo
    if ! locale -a 2>/dev/null | grep -qi 'es_AR.utf8\|es_AR.UTF-8'; then
        sudo sed -i 's/^# *es_AR.UTF-8 UTF-8/es_AR.UTF-8 UTF-8/' /etc/locale.gen
        # Si no estaba ni comentado, agregarlo
        if ! grep -q '^es_AR.UTF-8 UTF-8' /etc/locale.gen; then
            echo 'es_AR.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen >/dev/null
        fi
        sudo locale-gen
    fi
    # Setear como locale por defecto del sistema
    sudo update-locale LANG=es_AR.UTF-8 LC_ALL=es_AR.UTF-8 LANGUAGE=es_AR:es
    log_ok "Locale es_AR.UTF-8 configurado"
else
    log_warn "No se encontró /etc/locale.gen, se omite configuración de locale"
fi

# Zona horaria Argentina
if [ -f /usr/share/zoneinfo/America/Argentina/Buenos_Aires ]; then
    sudo ln -sf /usr/share/zoneinfo/America/Argentina/Buenos_Aires /etc/localtime
    echo 'America/Argentina/Buenos_Aires' | sudo tee /etc/timezone >/dev/null
    sudo dpkg-reconfigure -f noninteractive tzdata 2>/dev/null || true
    log_ok "Zona horaria: America/Argentina/Buenos_Aires"
else
    log_warn "Zoneinfo no disponible, se omite configuración de timezone"
fi

# Validar que supervisorctl esté disponible ANTES de proceder
ensure_cmd_or_install "supervisorctl" "supervisor" || {
    log_error "supervisor es requerido para pi_video_looper"
    exit 1
}

log_info "Instalando/validando pi_video_looper..."
# pi_video_looper usa supervisor (NO systemd). Verificamos via supervisorctl.
# NOTA: supervisorctl status devuelve 'video_looper: ERROR (no such process)' si no existe
#       — el texto 'video_looper' aparece igual, por eso verificamos RUNNING + conf file.
VIDEO_LOOPER_INSTALLED=false
if [ -f /etc/supervisor/conf.d/video_looper.conf ] && \
   command -v supervisorctl >/dev/null 2>&1 && \
   sudo supervisorctl status video_looper 2>/dev/null | grep -q 'RUNNING'; then
    VIDEO_LOOPER_INSTALLED=true
    log_info "Servicio video_looper ya existe en supervisor (RUNNING), se conserva instalacion"
elif sudo systemctl list-unit-files 2>/dev/null | grep -q '^video_looper\.service' && \
     [ -f /etc/supervisor/conf.d/video_looper.conf ]; then
    VIDEO_LOOPER_INSTALLED=true
    log_info "Servicio video_looper ya existe en systemd, se conserva instalacion"
fi

if [ "$VIDEO_LOOPER_INSTALLED" = "false" ]; then
    TMP_LOOPER_DIR="/tmp/pi_video_looper"
    rm -rf "$TMP_LOOPER_DIR"

    if command -v git >/dev/null 2>&1; then
        log_info "Descargando pi_video_looper via git..."
        git clone --depth 1 https://github.com/adafruit/pi_video_looper.git "$TMP_LOOPER_DIR"
    else
        log_warn "git no disponible, usando descarga ZIP de GitHub..."
        TMP_ZIP="/tmp/pi_video_looper.zip"
        rm -f "$TMP_ZIP"
        if command -v curl >/dev/null 2>&1; then
            curl -fL https://github.com/adafruit/pi_video_looper/archive/refs/heads/master.zip -o "$TMP_ZIP"
        else
            wget -O "$TMP_ZIP" https://github.com/adafruit/pi_video_looper/archive/refs/heads/master.zip
        fi
        unzip -q "$TMP_ZIP" -d /tmp
        mv /tmp/pi_video_looper-master "$TMP_LOOPER_DIR"
    fi

    if [ -f /boot/video_looper.ini ]; then
        sudo cp /boot/video_looper.ini /boot/video_looper.ini_backup.$(date +%s) || true
    fi

    if is_true "${VIDLOOP_NO_HELLO_VIDEO:-true}"; then
        sudo bash "$TMP_LOOPER_DIR/install.sh" no_hello_video
    else
        sudo bash "$TMP_LOOPER_DIR/install.sh"
    fi

    # Instalar omxplayer explícitamente (install.sh a veces no lo incluye en Buster)
    if ! command -v omxplayer >/dev/null 2>&1; then
        log_info "Instalando omxplayer..."
        sudo apt-get install -y omxplayer 2>/dev/null || \
            sudo apt-get install -y --no-install-recommends omxplayer || \
            log_warn "omxplayer no pudo instalarse – verificar manualmente"
    fi

    # Fix pygame: install.sh puede fallar por gcc-8-base version conflict en Buster+RPi.
    # Si python3-pygame no importa, forzar install con dpkg --force-depends y marcarlo hold.
    if ! python3 -c "import pygame" >/dev/null 2>&1; then
        log_warn "python3-pygame no disponible, aplicando install forzado..."
        # Instalar las dependencias SDL reales que pygame sí necesita en runtime
        sudo apt-get install -y --no-install-recommends \
            libsdl1.2debian libsdl-image1.2 libsdl-mixer1.2 libsdl-ttf2.0-0 \
            libportmidi0 libfreetype6 libjpeg62-turbo fonts-freefont-ttf 2>/dev/null || true
        # Descargar e instalar pygame saltando la cadena de deps numpy/gfortran
        _PYGAME_DEB="$(mktemp /tmp/python3-pygame-XXXX.deb)"
        if apt-get download python3-pygame -o Dir::Cache::Archives=/tmp 2>/dev/null; then
            _PYGAME_DEB_PATH="$(ls /tmp/python3-pygame*.deb 2>/dev/null | head -1)"
            [ -n "$_PYGAME_DEB_PATH" ] && sudo dpkg --force-depends -i "$_PYGAME_DEB_PATH" || true
        fi
        rm -f "$_PYGAME_DEB" /tmp/python3-pygame*.deb 2>/dev/null || true
        # Marcar hold para evitar que apt intente instalar numpy (gcc conflict)
        sudo apt-mark hold python3-pygame 2>/dev/null || true
        if python3 -c "import pygame" >/dev/null 2>&1; then
            log_ok "python3-pygame instalado correctamente (force mode)"
        else
            log_warn "python3-pygame sigue sin importar – verificar manualmente"
        fi
    fi
fi

# Desplegar video_looper.ini al path correcto: /boot/video_looper.ini
# (pi_video_looper lee siempre de /boot/, no de /opt/)
if [ -f "$SCRIPT_DIR/video_looper.ini" ]; then
    sudo cp "$SCRIPT_DIR/video_looper.ini" /boot/video_looper.ini
    sudo sed -i "s|/home/pi/VIDLOOP44|/home/${VIDLOOP_SYSTEM_USER}/VIDLOOP44|g" /boot/video_looper.ini
    sudo chmod 644 /boot/video_looper.ini
    log_ok "video_looper.ini desplegado en /boot/video_looper.ini"
else
    log_warn "No se encontro video_looper.ini junto al script, se mantiene config existente"
    # Al menos corregir el path del usuario en el ini existente
    if [ -f /boot/video_looper.ini ]; then
        sudo sed -i "s|/home/pi/VIDLOOP44|/home/${VIDLOOP_SYSTEM_USER}/VIDLOOP44|g" /boot/video_looper.ini
        log_info "Path de usuario corregido en /boot/video_looper.ini existente"
    fi
fi

# Wrapper systemd para compatibilidad con dashboard (pi_video_looper usa supervisor internamente)
log_info "Creando wrapper systemd para video_looper..."

# Eliminar drop-ins obsoletos que puedan conflictuar con Type=oneshot
sudo rm -rf /etc/systemd/system/video_looper.service.d/ 2>/dev/null || true

# Detectar nombre del servicio supervisor en este sistema
_SUPERVISOR_AFTER=""
if sudo systemctl list-unit-files 2>/dev/null | grep -q '^supervisord\.service'; then
    _SUPERVISOR_AFTER="After=supervisord.service"$'\n'"Requires=supervisord.service"
elif sudo systemctl list-unit-files 2>/dev/null | grep -q '^supervisor\.service'; then
    _SUPERVISOR_AFTER="After=supervisor.service"$'\n'"Requires=supervisor.service"
else
    _SUPERVISOR_AFTER="After=multi-user.target"
fi

# Detectar ruta de supervisorctl
_SUPERVISORCTL=$(command -v supervisorctl 2>/dev/null || echo "/usr/bin/supervisorctl")

sudo tee /etc/systemd/system/video_looper.service >/dev/null <<EOF
[Unit]
Description=VIDLOOP video_looper (supervisor wrapper)
${_SUPERVISOR_AFTER}

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${_SUPERVISORCTL} start video_looper
ExecStop=${_SUPERVISORCTL} stop video_looper
ExecReload=${_SUPERVISORCTL} restart video_looper

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable video_looper 2>/dev/null || true

# Activación robusta de video_looper con reintentos automáticos
log_info "Activando video_looper con validación de reintentos..."
VIDEO_LOOPER_START_ATTEMPTS=1
while [ $VIDEO_LOOPER_START_ATTEMPTS -le 3 ]; do
    if sudo systemctl start video_looper 2>/dev/null; then
        sleep 2
        if sudo systemctl is-active --quiet video_looper 2>/dev/null; then
            log_ok "video_looper activo en intento $VIDEO_LOOPER_START_ATTEMPTS"
            break
        fi
    fi
    if [ $VIDEO_LOOPER_START_ATTEMPTS -lt 3 ]; then
        log_warn "Intento $VIDEO_LOOPER_START_ATTEMPTS falló, reintentando en 2 segundos..."
        sleep 2
    fi
    VIDEO_LOOPER_START_ATTEMPTS=$((VIDEO_LOOPER_START_ATTEMPTS + 1))
done

if ! sudo systemctl is-active --quiet video_looper 2>/dev/null; then
    log_warn "No se pudo activar video_looper via systemd, intentando supervisorctl..."
    if command -v supervisorctl >/dev/null 2>&1; then
        sudo supervisorctl restart video_looper 2>/dev/null || true
    fi
fi
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

log_info "Instalando ZeroTier..."
if command -v zerotier-one >/dev/null 2>&1; then
    log_ok "ZeroTier ya está instalado"
elif sudo apt-get install -y zerotier-one 2>/dev/null; then
    log_ok "ZeroTier instalado vía APT"
elif command -v curl >/dev/null 2>&1; then
    log_info "Instalando ZeroTier via script oficial..."
    curl -fsSL https://install.zerotier.com | sudo bash
    log_ok "ZeroTier instalado vía script oficial"
else
    log_warn "No se pudo instalar ZeroTier. Instala manualmente: curl -fsSL https://install.zerotier.com | sudo bash"
fi

if command -v zerotier-one >/dev/null 2>&1; then
    sudo systemctl enable --now zerotier-one 2>/dev/null || true
    log_ok "ZeroTier activo"
fi

log_info "Configurando WireGuard (optimizado)..."
if is_true "${ENABLE_WIREGUARD:-true}"; then
    # Instalar wireguard y herramientas (sin resolvconf que conflicta con systemd en Buster)
    log_info "Instalando WireGuard y dependencias..."
    
    if sudo apt-get install -y wireguard wireguard-tools 2>/dev/null; then
        log_ok "WireGuard instalado"
    else
        log_error "No se pudo instalar WireGuard (wireguard y wireguard-tools)"
        exit 1
    fi
    
    # openresolv es compatible con systemd (no desinstala paquetes críticos)
    # Se intenta instalar pero no es obligatorio si ya existe otra solución DNS
    if ! command -v resolvectl >/dev/null 2>&1; then
        sudo apt-get install -y openresolv 2>/dev/null || log_warn "openresolv no disponible, se omite"
    fi

    WG_PATH="/etc/wireguard/${WG_INTERFACE}.conf"

    # ================================================================
    # AUTO-EXCHANGE: La RPi se registra sola en el VPS sin intervención
    # ================================================================
    # Modos disponibles (por orden de prioridad):
    #   1. VIDLOOP_WG_CONFIG_B64   — config ya generada externamente (deploy masivo)
    #   2. VIDLOOP_WG_CONFIG_TEXT  — config como texto plano
    #   3. VIDLOOP_WG_CONFIG_FILE  — ruta a archivo local
    #   4. VIDLOOP_WG_AUTO_EXCHANGE=true  — la RPi conecta al VPS, genera par de
    #      claves allí y se registra completamente sola (modo manual/campo)
    #   5. VIDLOOP_DOWNLOAD_WG_FROM_VPS — legacy: descarga config ya generada
    # ================================================================

    # ── Modo 4: AUTO-EXCHANGE completo RPi ↔ VPS ─────────────────
    # Activar con: VIDLOOP_WG_AUTO_EXCHANGE=true VIDLOOP_VPS_IP=82.25.77.55 ...
    if is_true "${VIDLOOP_WG_AUTO_EXCHANGE:-false}" \
       && [ -z "${VIDLOOP_WG_CONFIG_B64:-}" ] \
       && [ -z "${VIDLOOP_WG_CONFIG_TEXT:-}" ] \
       && [ -z "${VIDLOOP_WG_CONFIG_FILE:-}" ]; then

        log_info "Iniciando auto-exchange WireGuard con VPS..."

        _VPS_IP="${VIDLOOP_VPS_IP:-82.25.77.55}"
        _VPS_USER="${VIDLOOP_VPS_USER:-root}"
        _VPS_PASS="${VIDLOOP_VPS_PASS:-Vidloop@44tech}"
        _VPS_WG_IF="${VIDLOOP_VPS_WG_IF:-wg0}"
        # IP privada que se asignará a esta RPi (se puede sobreescribir)
        _RPI_WG_IP="${VIDLOOP_WG_RPI_IP:-}"
        # Nombre identificador de esta RPi en el VPS
        _RPI_NAME="${VIDLOOP_RPI_NAME:-$(hostname -s 2>/dev/null || echo "rpi-$(date +%s)")}"

        # Instalar sshpass si falta
        if ! command -v sshpass >/dev/null 2>&1; then
            log_info "Instalando sshpass para auto-exchange..."
            sudo apt-get install -y sshpass 2>/dev/null || {
                log_warn "sshpass no disponible: auto-exchange cancelado. Pasar VIDLOOP_WG_CONFIG_B64 manualmente."
            }
        fi

        if command -v sshpass >/dev/null 2>&1; then
            log_info "Generando y registrando peer en VPS $_VPS_IP..."

            # Script inline que corre EN el VPS vía SSH.
            # Recibe: $1=nombre_rpi $2=ip_wg(puede ser vacío) $3=interfaz_wg
            # Imprime: WG_CONFIG_B64=<base64_del_conf_de_la_RPi>
            _AUTO_WG_RESULT=$(sshpass -p "$_VPS_PASS" \
                ssh -o StrictHostKeyChecking=no \
                    -o ConnectTimeout=10 \
                    -o BatchMode=no \
                    "$_VPS_USER@$_VPS_IP" \
                    bash -s -- "$_RPI_NAME" "$_RPI_WG_IP" "$_VPS_WG_IF" \
                <<'VPS_INLINE'
#!/usr/bin/env bash
set -euo pipefail
RPI_NAME="$1"
RPI_WG_IP="$2"
WG_IF="$3"
WG_CONF="/etc/wireguard/${WG_IF}.conf"

# Validar que wg0 está activo
if ! ip link show "$WG_IF" >/dev/null 2>&1; then
    echo "ERROR: Interfaz $WG_IF no activa en VPS" >&2; exit 1
fi

# Extraer clave privada del servidor para derivar la pública
VPS_PRIVATE_KEY=$(grep -m1 '^\s*PrivateKey' "$WG_CONF" 2>/dev/null | awk '{print $3}' || true)
[ -z "$VPS_PRIVATE_KEY" ] && [ -f "/etc/wireguard/server.key" ] && VPS_PRIVATE_KEY=$(cat /etc/wireguard/server.key)
if [ -z "$VPS_PRIVATE_KEY" ]; then
    echo "ERROR: No se encontró clave privada del servidor en $WG_CONF" >&2; exit 1
fi
VPS_PUBLIC_KEY=$(echo "$VPS_PRIVATE_KEY" | wg pubkey)
WG_PORT=$(wg show "$WG_IF" listen-port 2>/dev/null || echo "51820")

# Detectar IP pública del VPS
VPS_PUBLIC_IP=""
[ -f /etc/wireguard/.vps_public_ip ] && VPS_PUBLIC_IP=$(cat /etc/wireguard/.vps_public_ip)
if [ -z "$VPS_PUBLIC_IP" ]; then
    VPS_PUBLIC_IP=$(curl -fs --max-time 4 ifconfig.me \
        || curl -fs --max-time 4 api.ipify.org \
        || echo "82.25.77.55")
    echo "$VPS_PUBLIC_IP" > /etc/wireguard/.vps_public_ip
fi

# Detectar subred WG del servidor
WG_NETWORK=$(ip addr show "$WG_IF" | grep 'inet ' | awk '{print $2}' | head -1)
[ -z "$WG_NETWORK" ] && WG_NETWORK="10.0.0.1/24"
WG_SUBNET="${WG_NETWORK%.*}.0/24"

# Auto-asignar IP para la RPi si no se pasó una
if [ -z "$RPI_WG_IP" ]; then
    # Encontrar el mayor octeto usado y sumar 1
    LAST_USED=$(wg show "$WG_IF" allowed-ips 2>/dev/null \
        | awk '{print $2}' \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.([0-9]+)' \
        | awk -F'.' '{print $4}' \
        | sort -n | tail -1 || echo "9")
    NEXT=$((LAST_USED + 1))
    [ "$NEXT" -lt 10 ] && NEXT=10
    [ "$NEXT" -gt 253 ] && { echo "ERROR: No hay IPs disponibles en la subred WG" >&2; exit 1; }
    NET_PREFIX="${WG_NETWORK%.*}"
    RPI_WG_IP="${NET_PREFIX}.${NEXT}"
fi

# Generar keypair PARA la RPi (en el VPS)
WORK=$(mktemp -d); trap "rm -rf $WORK" EXIT
wg genkey | tee "$WORK/rpi.key" | wg pubkey > "$WORK/rpi.pub"
RPI_PRIV=$(cat "$WORK/rpi.key")
RPI_PUB=$(cat "$WORK/rpi.pub")

# Eliminar peer anterior con la misma IP (si existe otro)
OLD_PEER=$(wg show "$WG_IF" allowed-ips 2>/dev/null \
    | grep "${RPI_WG_IP}/32" | awk '{print $1}' || true)
[ -n "$OLD_PEER" ] && [ "$OLD_PEER" != "$RPI_PUB" ] \
    && wg set "$WG_IF" peer "$OLD_PEER" remove 2>/dev/null || true

# Registrar peer en la interfaz (hot, sin reiniciar WG)
wg set "$WG_IF" peer "$RPI_PUB" allowed-ips "${RPI_WG_IP}/32"

# Persistir en wg0.conf (eliminar bloque previo con esta pubkey si existe)
if [ -f "$WG_CONF" ]; then
    TMP_CONF=$(mktemp)
    awk -v key="$RPI_PUB" '
        /^\[Peer\]/ { in_p=1; buf=""; skip=0 }
        in_p { buf = buf $0 "\n" }
        in_p && $0 ~ key { skip=1 }
        in_p && /^$/ { if(!skip) printf "%s\n", buf; in_p=0; buf=""; skip=0; next }
        !in_p { print }
        END { if(in_p && !skip) printf "%s", buf }
    ' "$WG_CONF" > "$TMP_CONF" && mv "$TMP_CONF" "$WG_CONF"
fi
printf '\n# Peer: %s — %s\n[Peer]\nPublicKey = %s\nAllowedIPs = %s/32\n' \
    "$RPI_NAME" "$(date -Iseconds)" "$RPI_PUB" "$RPI_WG_IP" >> "$WG_CONF"

# Construir wg0.conf PARA la RPi
cat > "$WORK/rpi_wg0.conf" <<RPICONF
[Interface]
PrivateKey = ${RPI_PRIV}
Address = ${RPI_WG_IP}/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${VPS_PUBLIC_KEY}
Endpoint = ${VPS_PUBLIC_IP}:${WG_PORT}
AllowedIPs = ${WG_SUBNET}
PersistentKeepalive = 25
RPICONF

# Devolver como base64 — UNA SOLA LÍNEA para parseo sencillo
echo "WG_CONFIG_B64=$(base64 -w0 "$WORK/rpi_wg0.conf" 2>/dev/null || base64 "$WORK/rpi_wg0.conf")"
VPS_INLINE
            ) || true  # no abortar el script si el auto-exchange falla

            # Parsear resultado
            _WG_B64=$(echo "$_AUTO_WG_RESULT" | grep "^WG_CONFIG_B64=" | cut -d= -f2- | tr -d '\n' || true)
            if [ -n "$_WG_B64" ]; then
                VIDLOOP_WG_CONFIG_B64="$_WG_B64"
                log_ok "Auto-exchange WireGuard completado para $_RPI_NAME"
            else
                log_warn "Auto-exchange falló o devolvió vacío. WireGuard instalado pero sin configurar."
                log_warn "Output VPS: $_AUTO_WG_RESULT"
            fi
        fi

    # ── Modo 5: Legacy — descargar config ya generada desde VPS ──
    elif [ -n "${VIDLOOP_DOWNLOAD_WG_FROM_VPS:-}" ] \
         && [ -z "${VIDLOOP_WG_CONFIG_B64:-}" ] \
         && [ -z "${VIDLOOP_WG_CONFIG_TEXT:-}" ] \
         && [ -z "${VIDLOOP_WG_CONFIG_FILE:-}" ]; then

        log_info "Descargando config WireGuard pre-generada desde VPS (modo legacy)..."
        _VPS_IP="${VIDLOOP_VPS_IP:-82.25.77.55}"
        _VPS_USER="${VIDLOOP_VPS_USER:-root}"
        _VPS_PASS="${VIDLOOP_VPS_PASS:-Vidloop@44tech}"

        if ! command -v sshpass >/dev/null 2>&1; then
            sudo apt-get install -y sshpass 2>/dev/null || true
        fi

        if command -v sshpass >/dev/null 2>&1; then
            _LEGACY_B64=$(sshpass -p "$_VPS_PASS" \
                ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
                    "$_VPS_USER@$_VPS_IP" \
                'f=$(ls -td /tmp/wireguard-* 2>/dev/null | head -1); [ -n "$f" ] && cat "$f/wg0.conf" | base64 -w0 2>/dev/null || base64 "$f/wg0.conf"' \
                2>/dev/null || echo "")
            if [ -n "$_LEGACY_B64" ]; then
                VIDLOOP_WG_CONFIG_B64="$_LEGACY_B64"
                log_ok "Config WireGuard descargada desde VPS (legacy)"
            else
                log_warn "No se encontró config pre-generada en VPS"
            fi
        fi
    fi

    # ── Aplicar configuración (cualquier modo) ───────────────────
    if [ -n "${VIDLOOP_WG_CONFIG_B64:-}" ]; then
        echo "${VIDLOOP_WG_CONFIG_B64}" | base64 -d | sudo tee "$WG_PATH" >/dev/null
        log_ok "Config WireGuard aplicada desde base64"
    elif [ -n "${VIDLOOP_WG_CONFIG_TEXT:-}" ]; then
        printf '%s\n' "${VIDLOOP_WG_CONFIG_TEXT}" | sudo tee "$WG_PATH" >/dev/null
        log_ok "Config WireGuard aplicada desde texto"
    elif [ -n "${VIDLOOP_WG_CONFIG_FILE:-}" ] && [ -f "${VIDLOOP_WG_CONFIG_FILE}" ]; then
        sudo install -m 0600 "${VIDLOOP_WG_CONFIG_FILE}" "$WG_PATH"
        log_ok "Config WireGuard aplicada desde archivo"
    else
        log_warn "ENABLE_WIREGUARD=true pero no hay config disponible."
        log_warn "Opciones: VIDLOOP_WG_CONFIG_B64 | VIDLOOP_WG_AUTO_EXCHANGE=true | VIDLOOP_WG_CONFIG_FILE"
        log_warn "WireGuard instalado pero interfaz no levantada."
    fi

    if [ -f "$WG_PATH" ]; then
        sudo chmod 600 "$WG_PATH"
        sudo systemctl enable --now "wg-quick@${WG_INTERFACE}"
        log_ok "WireGuard activo en interfaz ${WG_INTERFACE}"
    fi
else
    log_info "WireGuard desactivado (ENABLE_WIREGUARD=false)"
fi

log_info "Configurando usuario ${VIDLOOP_SYSTEM_USER}..."
if ! id -u "$VIDLOOP_SYSTEM_USER" >/dev/null 2>&1; then
    sudo adduser --disabled-password --gecos "" "$VIDLOOP_SYSTEM_USER"
    sudo usermod -aG sudo "$VIDLOOP_SYSTEM_USER"
    log_ok "Usuario $VIDLOOP_SYSTEM_USER creado"
else
    log_info "Usuario $VIDLOOP_SYSTEM_USER ya existe"
    # Asegurar que el usuario tiene permisos sudo
    if ! sudo -l -U "$VIDLOOP_SYSTEM_USER" 2>/dev/null | grep -q '(ALL)'; then
        sudo usermod -aG sudo "$VIDLOOP_SYSTEM_USER"
        log_info "Permisos sudo agregados a $VIDLOOP_SYSTEM_USER"
    fi
fi

# Agregar usuario 'pi' al grupo vidloop si existe (compatibilidad con instalaciones existentes)
if id -u pi >/dev/null 2>&1; then
    sudo usermod -aG "${VIDLOOP_SYSTEM_USER}" pi 2>/dev/null || true
    log_info "Usuario 'pi' agregado al grupo $VIDLOOP_SYSTEM_USER"
fi

ADMIN_PASS="$VIDLOOP_SYSTEM_PASS"
if [ -z "$ADMIN_PASS" ]; then
    if is_true "$VIDLOOP_NONINTERACTIVE"; then
        ADMIN_PASS="$(generate_password)"
        log_warn "Password vacía detectada de forma inesperada, se generó una clave automática para ${VIDLOOP_SYSTEM_USER}"
    else
        while true; do
            read -rsp "Ingresa nueva clave para usuario ${VIDLOOP_SYSTEM_USER}: " ADMIN_PASS
            echo
            read -rsp "Confirma clave para usuario ${VIDLOOP_SYSTEM_USER}: " ADMIN_PASS_CONFIRM
            echo
            if [ -z "$ADMIN_PASS" ]; then
                log_warn "La clave no puede estar vacía"
                continue
            fi
            if [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ]; then
                log_warn "Las claves no coinciden, intenta de nuevo"
                continue
            fi
            break
        done
        unset ADMIN_PASS_CONFIRM
    fi
fi

echo "${VIDLOOP_SYSTEM_USER}:${ADMIN_PASS}" | sudo chpasswd
if is_true "$VIDLOOP_NONINTERACTIVE"; then
    sudo install -d -m 0700 /root/.vidloop
    printf 'ssh_user=%s\nssh_password=%s\ncreated_at=%s\n' "$VIDLOOP_SYSTEM_USER" "$ADMIN_PASS" "$(date -Iseconds)" | sudo tee /root/.vidloop/admin_credentials.txt >/dev/null
    sudo chmod 600 /root/.vidloop/admin_credentials.txt
    log_info "Credenciales guardadas en /root/.vidloop/admin_credentials.txt"
fi
unset ADMIN_PASS
log_ok "Usuario ${VIDLOOP_SYSTEM_USER} configurado"

VIDEO_DIR="/home/${VIDLOOP_SYSTEM_USER}/VIDLOOP44"
sudo mkdir -p "$VIDEO_DIR"
sudo chown -R "${VIDLOOP_SYSTEM_USER}:${VIDLOOP_SYSTEM_USER}" "$VIDEO_DIR"
# Permisos 775 para que el grupo vidloop pueda escribir (crítico para operación remota)
sudo chmod 755 "$VIDEO_DIR"
sudo chmod g+w "$VIDEO_DIR"
log_ok "Carpeta de videos lista en $VIDEO_DIR (permisos 775 aplicados)"

if is_true "$VIDLOOP_ENABLE_MEDIA_NORMALIZER"; then
        if ! [[ "$VIDLOOP_IMAGE_DURATION_SEC" =~ ^[0-9]+$ ]] || [ "$VIDLOOP_IMAGE_DURATION_SEC" -lt 1 ]; then
                log_warn "VIDLOOP_IMAGE_DURATION_SEC invalido, usando 20"
                VIDLOOP_IMAGE_DURATION_SEC=20
        fi
        if ! [[ "$VIDLOOP_IMAGE_SCAN_INTERVAL_MIN" =~ ^[0-9]+$ ]] || [ "$VIDLOOP_IMAGE_SCAN_INTERVAL_MIN" -lt 1 ]; then
                log_warn "VIDLOOP_IMAGE_SCAN_INTERVAL_MIN invalido, usando 1"
                VIDLOOP_IMAGE_SCAN_INTERVAL_MIN=1
        fi

        log_info "Configurando normalizador de media (imagenes -> mp4)..."

        sudo tee /usr/local/bin/vidloop-media-normalizer.sh >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail

MEDIA_DIR="/home/${VIDLOOP_SYSTEM_USER}/VIDLOOP44"
DURATION_SEC="${VIDLOOP_IMAGE_DURATION_SEC}"
MANIFEST="\$MEDIA_DIR/.source_manifest"
CHANGED=0

if ! command -v ffmpeg >/dev/null 2>&1; then exit 0; fi
if [ ! -d "\$MEDIA_DIR" ]; then exit 0; fi

if [ ! -f "\$MANIFEST" ]; then echo '' > "\$MANIFEST"; fi

# PASO 1: Procesar fotos NUEVAS o MODIFICADAS
shopt -s nullglob
for src in "\$MEDIA_DIR"/*.{jpg,jpeg,png,webp,JPG,JPEG,PNG,WEBP}; do
    [ -f "\$src" ] || continue
    base="\$(basename "\$src")"
    stem="\${base%.*}"
    out="\$MEDIA_DIR/__img__\${stem}.mp4"

    if [ ! -f "\$out" ] || [ "\$src" -nt "\$out" ]; then
        ffmpeg -y -loop 1 -t "\$DURATION_SEC" -i "\$src" \
            -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -pix_fmt yuv420p -r 25 "\$out" >/dev/null 2>&1 && CHANGED=1 || true
    fi
    grep -Fxq "\$base" "\$MANIFEST" 2>/dev/null || echo "\$base" >> "\$MANIFEST"
done

# PASO 2: LIMPIAR FOTOS ELIMINADAS - foto borrada = mp4 huérfano borrado
temp_manifest="\$(mktemp)"
while IFS= read -r stored_photo; do
    [ -z "\$stored_photo" ] && continue
    found=0
    for ext in jpg jpeg png webp JPG JPEG PNG WEBP; do
        if [ -f "\$MEDIA_DIR/\$stored_photo" ] 2>/dev/null; then
            found=1
            break
        fi
    done
    if [ \$found -eq 0 ]; then
        stem="\${stored_photo%.*}"
        orphan="\$MEDIA_DIR/__img__\${stem}.mp4"
        [ -f "\$orphan" ] && rm -f "\$orphan" && CHANGED=1
    else
        echo "\$stored_photo" >> "\$temp_manifest"
    fi
done < "\$MANIFEST"
mv "\$temp_manifest" "\$MANIFEST"

# PASO 3: Concatenar en UN archivo seamless (0ms gap)
CONCAT_OUT="\$MEDIA_DIR/__seamless_playlist__.mp4"
CONCAT_LIST="\$MEDIA_DIR/.concat_list.txt"
MP4_COUNT=0
> "\$CONCAT_LIST"
for mp4 in \$(ls -1 "\$MEDIA_DIR"/__img__*.mp4 2>/dev/null | sort); do
    [ -f "\$mp4" ] || continue
    echo "file '\$mp4'" >> "\$CONCAT_LIST"
    MP4_COUNT=\$((MP4_COUNT + 1))
done

if [ \$MP4_COUNT -gt 1 ]; then
    NEW_HASH="\$(md5sum "\$CONCAT_LIST" | cut -d' ' -f1)"
    OLD_HASH=""
    HASH_FILE="\$MEDIA_DIR/.concat.hash"
    [ -f "\$HASH_FILE" ] && OLD_HASH="\$(cat \$HASH_FILE)"
    if [ "\$CHANGED" -eq 1 ] || [ ! -f "\$CONCAT_OUT" ] || [ "\$NEW_HASH" != "\$OLD_HASH" ]; then
        ffmpeg -y -f concat -safe 0 -i "\$CONCAT_LIST" -c copy "\$CONCAT_OUT" >/dev/null 2>&1 && {
            echo "\$NEW_HASH" > "\$HASH_FILE"
            CHANGED=1
        } || true
    fi
elif [ \$MP4_COUNT -eq 1 ]; then
    rm -f "\$CONCAT_OUT"
else
    rm -f "\$CONCAT_OUT"
fi
rm -f "\$CONCAT_LIST"

if [ \$CHANGED -eq 1 ]; then
    supervisorctl restart video_looper >/dev/null 2>&1 || systemctl restart video_looper >/dev/null 2>&1 || true
fi

EOF
        sudo chmod +x /usr/local/bin/vidloop-media-normalizer.sh

        sudo tee /etc/systemd/system/vidloop-media-normalizer.service >/dev/null <<'EOF'
[Unit]
Description=VIDLOOP media normalizer (images to mp4)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vidloop-media-normalizer.sh
EOF

        sudo tee /etc/systemd/system/vidloop-media-normalizer.timer >/dev/null <<EOF
[Unit]
Description=Run VIDLOOP media normalizer periodically

[Timer]
OnBootSec=30s
OnUnitActiveSec=${VIDLOOP_IMAGE_SCAN_INTERVAL_MIN}min
Unit=vidloop-media-normalizer.service

[Install]
WantedBy=timers.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable --now vidloop-media-normalizer.timer
        sudo systemctl start vidloop-media-normalizer.service || true
        log_ok "Normalizador de media activo"
else
        log_info "Normalizador de media desactivado (VIDLOOP_ENABLE_MEDIA_NORMALIZER=false)"
fi

log_info "Endureciendo SSH..."
SSHD="/etc/ssh/sshd_config"
sudo cp "$SSHD" "${SSHD}.bak.$(date +%s)"

# Forzamos password auth por defecto para despliegues remotos en campo.
SSH_CONF_D="/etc/ssh/sshd_config.d"
sudo mkdir -p "$SSH_CONF_D"
sudo tee "$SSH_CONF_D/00-vidloop-auth.conf" >/dev/null <<'EOF'
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
PubkeyAuthentication yes
EOF

if is_true "${ENABLE_SSH_PASSWORD_AUTH:-true}"; then
    upsert_kv "$SSHD" "PasswordAuthentication" "yes"
    log_warn "PasswordAuthentication habilitado (default: true)"
else
    if user_has_authorized_keys "$VIDLOOP_SYSTEM_USER" || user_has_authorized_keys "pi"; then
        upsert_kv "$SSHD" "PasswordAuthentication" "no"
        sudo tee "$SSH_CONF_D/00-vidloop-auth.conf" >/dev/null <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
PubkeyAuthentication yes
EOF
    else
        upsert_kv "$SSHD" "PasswordAuthentication" "yes"
        log_warn "No hay authorized_keys detectadas; se mantiene PasswordAuthentication=yes para evitar bloqueo remoto"
    fi
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
    AUTOSTART="/home/${VIDLOOP_SYSTEM_USER}/.config/lxsession/LXDE-pi/autostart"
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
# Guard: no ejecutar si ya hay HDMI keepalive activo
if pgrep -f hdmi-keepalive.sh | grep -vq $$; then
    exit 0
fi
while true; do
    if tvservice -s 2>/dev/null | grep -q "TV is off"; then
        log_msg="[HDMI] Intentando reconexi+on"
        tvservice -p 2>/dev/null || true
        # chvt solo si fbset está disponible para cambiar de VT
        if command -v fbset >/dev/null 2>&1; then
            chvt 6 2>/dev/null && sleep 0.5 && chvt 7 2>/dev/null || true
        fi
    fi
    sleep 10
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
RestartSec=5
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now hdmi-keepalive.service 2>/dev/null || true
    log_ok "HDMI keepalive activo"
else
    log_warn "tvservice no disponible: se omite servicio HDMI keepalive"
fi

# ================================================================
# VALIDACIÓN POST-INSTALACIÓN
# ================================================================
echo
log_info "Ejecutando validación post-instalación..."
echo
log_info "Estado de servicios críticos:"

# Verificar video_looper
if sudo systemctl is-active --quiet video_looper 2>/dev/null; then
    log_ok "✓ video_looper está ACTIVO"
else
    log_warn "✗ video_looper está INACTIVO o indisponible"
fi

# Verificar permisos VIDLOOP44
VIDLOOP44_PATH="/home/${VIDLOOP_SYSTEM_USER}/VIDLOOP44"
if [ -d "$VIDLOOP44_PATH" ]; then
    PERMS=$(stat -c '%a' "$VIDLOOP44_PATH" 2>/dev/null || stat -f '%OLp' "$VIDLOOP44_PATH" | tail -c 4)
    log_ok "✓ Carpeta VIDLOOP44 existe con permisos $PERMS"
else
    log_warn "✗ Carpeta VIDLOOP44 no existe"
fi

# Verificar grupo vidloop
if getent group "${VIDLOOP_SYSTEM_USER}" >/dev/null 2>&1; then
    log_ok "✓ Grupo $VIDLOOP_SYSTEM_USER existe"
else
    log_warn "✗ Grupo $VIDLOOP_SYSTEM_USER no existe"
fi

# Verificar usuario pi en grupo vidloop
if id pi >/dev/null 2>&1 && id -Gn pi | grep -q "${VIDLOOP_SYSTEM_USER}"; then
    log_ok "✓ Usuario 'pi' pertenece al grupo $VIDLOOP_SYSTEM_USER"
elif id pi >/dev/null 2>&1; then
    log_warn "⚠ Usuario 'pi' existe pero NO pertenece a grupo $VIDLOOP_SYSTEM_USER"
fi

# Verificar SSH
if sudo systemctl is-active --quiet ssh 2>/dev/null || sudo systemctl is-active --quiet sshd 2>/dev/null; then
    log_ok "✓ SSH está ACTIVO"
else
    log_warn "✗ SSH está INACTIVO"
fi

# Verificar WireGuard si está habilitado
if is_true "${ENABLE_WIREGUARD:-true}"; then
    if ip link show "${WG_INTERFACE}" >/dev/null 2>&1; then
        log_ok "✓ WireGuard interfaz ${WG_INTERFACE} está ACTIVA"
    else
        log_warn "⚠ WireGuard interfaz ${WG_INTERFACE} no está activa (config pendiente)"
    fi
fi

# Verificar ZeroTier
if command -v zerotier-one >/dev/null 2>&1; then
    if sudo systemctl is-active --quiet zerotier-one 2>/dev/null; then
        log_ok "✓ ZeroTier está ACTIVO"
    else
        log_warn "⚠ ZeroTier instalado pero NO activo"
    fi
fi

echo
log_ok "Validación post-instalación completada"
echo
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}     VIDLOOP V3.0 - SETUP COMPLETADO          ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "${YELLOW}Usuario SSH:${NC} ${VIDLOOP_SYSTEM_USER}"
echo -e "${YELLOW}Password SSH:${NC} ${VIDLOOP_SYSTEM_PASS}"
echo -e "${YELLOW}Carpeta videos:${NC} /home/${VIDLOOP_SYSTEM_USER}/VIDLOOP44"
echo -e "${YELLOW}Nota:${NC} PasswordAuthentication por defecto queda en SI"

if is_true "$VIDLOOP_AUTO_REBOOT"; then
    log_info "Reinicio automatico habilitado (VIDLOOP_AUTO_REBOOT=true)"
    sleep 3
    sudo reboot
else
    log_info "VIDLOOP_AUTO_REBOOT=false, reinicia manualmente: sudo reboot"
fi
