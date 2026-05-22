#!/bin/sh
set -eu

# ================================================================
#                         VIDLOOP 2.0
#                Ignace - Powered by 44 Contenidos
# ================================================================

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "$0")"

VIDLOOP_USER="${VIDLOOP_USER:-vidloop}"
VIDLOOP_PASSWORD="${VIDLOOP_PASSWORD:-4455}"
if [ -n "${VIDLOOP_MEDIA_DIR:-}" ]; then
    VIDLOOP_MEDIA_DIR_EXPLICIT="true"
else
    VIDLOOP_MEDIA_DIR_EXPLICIT="false"
fi
VIDLOOP_MEDIA_DIR="${VIDLOOP_MEDIA_DIR:-/home/$VIDLOOP_USER/VIDLOOP44}"
VIDLOOP_IMAGE_DURATION_SEC="${VIDLOOP_IMAGE_DURATION_SEC:-20}"
VIDLOOP_WAIT_SEC="${VIDLOOP_WAIT_SEC:-0}"
VIDLOOP_TTY="${VIDLOOP_TTY:-1}"
VIDLOOP_VIDEO_ASPECT_MODE="${VIDLOOP_VIDEO_ASPECT_MODE:-fill}"
VIDLOOP_ZT_NETWORK_ID="${VIDLOOP_ZT_NETWORK_ID:-}"
VIDLOOP_AUTO_REBOOT="${VIDLOOP_AUTO_REBOOT:-false}"
VIDLOOP_FULL_UPGRADE="${VIDLOOP_FULL_UPGRADE:-false}"
VIDLOOP_ENABLE_HDMI_KEEPALIVE="${VIDLOOP_ENABLE_HDMI_KEEPALIVE:-true}"
VIDLOOP_DISABLE_TTY_GETTY="${VIDLOOP_DISABLE_TTY_GETTY:-true}"
VIDLOOP_BOOT_BLACK_DELAY_SEC="${VIDLOOP_BOOT_BLACK_DELAY_SEC:-2}"
VIDLOOP_HDMI_GROUP="${VIDLOOP_HDMI_GROUP:-1}"
VIDLOOP_HDMI_MODE="${VIDLOOP_HDMI_MODE:-16}"
VIDLOOP_HDMI_BOOST="${VIDLOOP_HDMI_BOOST:-7}"
VIDLOOP_HDMI_IGNORE_EDID="${VIDLOOP_HDMI_IGNORE_EDID:-false}"
VIDLOOP_QUIET_BOOT="${VIDLOOP_QUIET_BOOT:-true}"
VIDLOOP_LOGO_PATH="${VIDLOOP_LOGO_PATH:-}"
ENABLE_SSH_PASSWORD_AUTH="${ENABLE_SSH_PASSWORD_AUTH:-true}"

ORANGE='\033[38;5;208m'
WHITE='\033[1;37m'
DIM='\033[2;37m'
GREEN='\033[38;5;118m'
YELLOW='\033[38;5;226m'
RED='\033[38;5;196m'
BLACK_BG='\033[40m'
NC='\033[0m'

apply_installer_theme() {
    printf "%b%b" "$BLACK_BG" "$WHITE"
}

reset_installer_theme() {
    printf "%b" "$NC"
}

log_info()  { printf "%b[INFO]%b %s\n" "$ORANGE" "$NC$WHITE" "$*"; }
log_ok()    { printf "%b[ OK ]%b %s\n" "$GREEN" "$NC$WHITE" "$*"; }
log_warn()  { printf "%b[WARN]%b %s\n" "$YELLOW" "$NC$WHITE" "$*"; }
log_error() { printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$*"; }

trap reset_installer_theme EXIT
apply_installer_theme

is_true() {
    case "${1:-}" in
        1|true|TRUE|yes|YES|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

usage() {
    cat <<EOF
VIDLOOP MIXED installer $SCRIPT_VERSION

Uso:
  sudo ./install.sh [opciones]

Opciones:
  --zt-network ID       Une la Raspberry a una red ZeroTier
  --user USER           Usuario SSH/operativo. Default: $VIDLOOP_USER
  --password PASS       Password del usuario. Default: $VIDLOOP_PASSWORD
  --media-dir PATH      Carpeta de imagenes/videos. Default: $VIDLOOP_MEDIA_DIR
  --logo PATH/URL       Ruta local o URL (http/https) a la imagen de logo
  --image-duration SEC  Duracion de cada imagen. Default: $VIDLOOP_IMAGE_DURATION_SEC
  --auto-reboot         Reinicia al finalizar
  --no-reboot           No reinicia al finalizar
  --help                Muestra esta ayuda

Tambien se puede configurar por variables de entorno:
  VIDLOOP_ZT_NETWORK_ID, VIDLOOP_USER, VIDLOOP_PASSWORD,
  VIDLOOP_MEDIA_DIR, VIDLOOP_IMAGE_DURATION_SEC, VIDLOOP_AUTO_REBOOT,
  VIDLOOP_TTY, VIDLOOP_BOOT_BLACK_DELAY_SEC, VIDLOOP_QUIET_BOOT,
  VIDLOOP_HDMI_GROUP, VIDLOOP_HDMI_MODE, VIDLOOP_HDMI_BOOST,
  VIDLOOP_HDMI_IGNORE_EDID
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --zt-network)
            [ "$#" -ge 2 ] || { log_error "Falta valor para --zt-network"; exit 1; }
            VIDLOOP_ZT_NETWORK_ID="$2"
            shift 2
            ;;
        --user)
            [ "$#" -ge 2 ] || { log_error "Falta valor para --user"; exit 1; }
            VIDLOOP_USER="$2"
            if ! is_true "$VIDLOOP_MEDIA_DIR_EXPLICIT"; then
                VIDLOOP_MEDIA_DIR="/home/$VIDLOOP_USER/VIDLOOP44"
            fi
            shift 2
            ;;
        --password)
            [ "$#" -ge 2 ] || { log_error "Falta valor para --password"; exit 1; }
            VIDLOOP_PASSWORD="$2"
            shift 2
            ;;
        --media-dir)
            [ "$#" -ge 2 ] || { log_error "Falta valor para --media-dir"; exit 1; }
            VIDLOOP_MEDIA_DIR="$2"
            VIDLOOP_MEDIA_DIR_EXPLICIT="true"
            shift 2
            ;;
        --logo)
            [ "$#" -ge 2 ] || { log_error "Falta valor para --logo"; exit 1; }
            VIDLOOP_LOGO_PATH="$2"
            shift 2
            ;;
        --image-duration)
            [ "$#" -ge 2 ] || { log_error "Falta valor para --image-duration"; exit 1; }
            VIDLOOP_IMAGE_DURATION_SEC="$2"
            shift 2
            ;;
        --auto-reboot)
            VIDLOOP_AUTO_REBOOT="true"
            shift
            ;;
        --no-reboot)
            VIDLOOP_AUTO_REBOOT="false"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Opcion desconocida: $1"
            usage
            exit 1
            ;;
    esac
done

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        log_info "Reejecutando con sudo..."
        exec sudo \
            VIDLOOP_USER="$VIDLOOP_USER" \
            VIDLOOP_PASSWORD="$VIDLOOP_PASSWORD" \
            VIDLOOP_MEDIA_DIR="$VIDLOOP_MEDIA_DIR" \
            VIDLOOP_IMAGE_DURATION_SEC="$VIDLOOP_IMAGE_DURATION_SEC" \
            VIDLOOP_WAIT_SEC="$VIDLOOP_WAIT_SEC" \
            VIDLOOP_TTY="$VIDLOOP_TTY" \
            VIDLOOP_VIDEO_ASPECT_MODE="$VIDLOOP_VIDEO_ASPECT_MODE" \
            VIDLOOP_ZT_NETWORK_ID="$VIDLOOP_ZT_NETWORK_ID" \
            VIDLOOP_AUTO_REBOOT="$VIDLOOP_AUTO_REBOOT" \
            VIDLOOP_FULL_UPGRADE="$VIDLOOP_FULL_UPGRADE" \
            VIDLOOP_ENABLE_HDMI_KEEPALIVE="$VIDLOOP_ENABLE_HDMI_KEEPALIVE" \
            VIDLOOP_DISABLE_TTY_GETTY="$VIDLOOP_DISABLE_TTY_GETTY" \
            VIDLOOP_BOOT_BLACK_DELAY_SEC="$VIDLOOP_BOOT_BLACK_DELAY_SEC" \
            VIDLOOP_HDMI_GROUP="$VIDLOOP_HDMI_GROUP" \
            VIDLOOP_HDMI_MODE="$VIDLOOP_HDMI_MODE" \
            VIDLOOP_HDMI_BOOST="$VIDLOOP_HDMI_BOOST" \
            VIDLOOP_HDMI_IGNORE_EDID="$VIDLOOP_HDMI_IGNORE_EDID" \
            VIDLOOP_QUIET_BOOT="$VIDLOOP_QUIET_BOOT" \
            VIDLOOP_LOGO_PATH="$VIDLOOP_LOGO_PATH" \
            ENABLE_SSH_PASSWORD_AUTH="$ENABLE_SSH_PASSWORD_AUTH" \
            /bin/sh "$SCRIPT_PATH" "$@"
    fi
    log_error "Este instalador requiere root. Ejecuta: sudo ./install.sh"
    exit 1
fi

validate_uint_min() {
    name="$1"
    value="$2"
    min="$3"

    if ! printf '%s' "$value" | grep -Eq '^[0-9]+$'; then
        log_error "$name debe ser numerico"
        exit 1
    fi
    if [ "$value" -lt "$min" ]; then
        log_error "$name debe ser mayor o igual a $min"
        exit 1
    fi
}

validate_uint_range() {
    name="$1"
    value="$2"
    min="$3"
    max="$4"

    validate_uint_min "$name" "$value" "$min"
    if [ "$value" -gt "$max" ]; then
        log_error "$name debe ser menor o igual a $max"
        exit 1
    fi
}

validate_username() {
    if ! printf '%s' "$VIDLOOP_USER" | grep -Eq '^[a-z_][a-z0-9_-]*[$]?$'; then
        log_error "VIDLOOP_USER invalido: $VIDLOOP_USER"
        exit 1
    fi
}

if [ -n "$VIDLOOP_LOGO_PATH" ]; then
    if printf '%s' "$VIDLOOP_LOGO_PATH" | grep -Eq '^https?://'; then
        log_info "Descargando logo desde URL..."
        TMP_LOGO="/tmp/vidloop_logo_download.png"
        if curl -sSLf -o "$TMP_LOGO" "$VIDLOOP_LOGO_PATH" || wget -qO "$TMP_LOGO" "$VIDLOOP_LOGO_PATH"; then
            VIDLOOP_LOGO_PATH="$TMP_LOGO"
        else
            log_error "Fallo al descargar el logo desde $VIDLOOP_LOGO_PATH"
            exit 1
        fi
    elif [ ! -f "$VIDLOOP_LOGO_PATH" ]; then
        log_error "El archivo de logo no existe: $VIDLOOP_LOGO_PATH"
        exit 1
    fi
fi

validate_username
validate_uint_min "VIDLOOP_IMAGE_DURATION_SEC" "$VIDLOOP_IMAGE_DURATION_SEC" 1
validate_uint_min "VIDLOOP_WAIT_SEC" "$VIDLOOP_WAIT_SEC" 0
validate_uint_range "VIDLOOP_TTY" "$VIDLOOP_TTY" 1 63
validate_uint_min "VIDLOOP_BOOT_BLACK_DELAY_SEC" "$VIDLOOP_BOOT_BLACK_DELAY_SEC" 0
validate_uint_min "VIDLOOP_HDMI_MODE" "$VIDLOOP_HDMI_MODE" 1
validate_uint_range "VIDLOOP_HDMI_BOOST" "$VIDLOOP_HDMI_BOOST" 0 11

case "$VIDLOOP_HDMI_GROUP" in
    1|2) ;;
    *)
        log_error "VIDLOOP_HDMI_GROUP debe ser 1 (CEA/TV) o 2 (DMT/monitor)"
        exit 1
        ;;
esac

case "$VIDLOOP_VIDEO_ASPECT_MODE" in
    fill|letterbox|stretch) ;;
    *)
        log_error "VIDLOOP_VIDEO_ASPECT_MODE invalido: $VIDLOOP_VIDEO_ASPECT_MODE"
        exit 1
        ;;
esac

case "$VIDLOOP_MEDIA_DIR" in
    /*) ;;
    *)
        log_error "VIDLOOP_MEDIA_DIR debe ser una ruta absoluta"
        exit 1
        ;;
esac
case "$VIDLOOP_MEDIA_DIR" in
    *\"*|*' '*)
        log_error "VIDLOOP_MEDIA_DIR formato invalido"
        exit 1
        ;;
esac
if printf '%s' "$VIDLOOP_MEDIA_DIR" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    log_error "VIDLOOP_MEDIA_DIR no puede contener caracteres de control"
    exit 1
fi

case "$VIDLOOP_PASSWORD" in
    *:*) log_error "VIDLOOP_PASSWORD no puede contener ':'"; exit 1 ;;
    *' '*) log_error "VIDLOOP_PASSWORD formato invalido"; exit 1 ;;
esac
if printf '%s' "$VIDLOOP_PASSWORD" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    log_error "VIDLOOP_PASSWORD no puede contener caracteres de control"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Falta comando requerido: $1"
        exit 1
    fi
}

codename() {
    if command -v lsb_release >/dev/null 2>&1; then
        lsb_release -sc 2>/dev/null || true
        return
    fi
    if [ -r /etc/os-release ]; then
        sed -n 's/^VERSION_CODENAME=//p' /etc/os-release | tr -d '"'
        return
    fi
    printf ''
}

backup_once() {
    file="$1"
    timestamp="$(date +%Y%m%d%H%M%S)"
    backup_file="$file.vidloop.$timestamp.bak"
    counter=1

    [ -f "$file" ] || return 0
    while [ -e "$backup_file" ]; do
        backup_file="$file.vidloop.$timestamp.$counter.bak"
        counter=$((counter + 1))
    done
    cp "$file" "$backup_file" 2>/dev/null || true
}

configure_buster_repos() {
    os_codename="$(codename)"
    [ "$os_codename" = "buster" ] || return 0

    log_warn "Raspberry Pi OS Buster detectado; configurando repositorios legacy/archive."
    backup_once /etc/apt/sources.list

    if [ -f /etc/apt/sources.list ]; then
        sed -i 's|^deb \(.*raspbian\.org.*\)|# deb \1|g' /etc/apt/sources.list 2>/dev/null || true
        sed -i 's|^deb \(.*raspberrypi\.org.*\)|# deb \1|g' /etc/apt/sources.list 2>/dev/null || true
        sed -i 's|^deb \(.*archive\.debian\.org.*\)|# deb \1|g' /etc/apt/sources.list 2>/dev/null || true
        sed -i 's|^deb-src \(.*\)|# deb-src \1|g' /etc/apt/sources.list 2>/dev/null || true
    fi

    for source_file in /etc/apt/sources.list.d/*.list; do
        [ -f "$source_file" ] || continue
        case "$source_file" in
            *vidloop-buster*) continue ;;
        esac
        backup_once "$source_file"
        sed -i 's|^deb \(.*raspbian\.org.*\)|# deb \1|g' "$source_file" 2>/dev/null || true
        sed -i 's|^deb \(.*raspberrypi\.org.*\)|# deb \1|g' "$source_file" 2>/dev/null || true
        sed -i 's|^deb \(.*archive\.debian\.org.*\)|# deb \1|g' "$source_file" 2>/dev/null || true
        sed -i 's|^deb-src \(.*\)|# deb-src \1|g' "$source_file" 2>/dev/null || true
    done

    cat > /etc/apt/sources.list.d/vidloop-buster-legacy.list <<'EOF'
deb [trusted=yes] http://legacy.raspbian.org/raspbian/ buster main contrib non-free rpi
deb [trusted=yes] http://archive.raspberrypi.org/debian/ buster main
deb [trusted=yes] http://archive.debian.org/debian buster main contrib non-free
deb [trusted=yes] http://archive.debian.org/debian-security buster/updates main contrib non-free
EOF

    mkdir -p /etc/apt/apt.conf.d
    cat > /etc/apt/apt.conf.d/99-vidloop-buster <<'EOF'
Acquire::Check-Valid-Until "false";
APT::Get::AllowUnauthenticated "true";
EOF
}

apt_update() {
    if apt-get update -o Acquire::Check-Valid-Until=false; then
        return 0
    fi
    configure_buster_repos
    apt-get update -o Acquire::Check-Valid-Until=false
}

apt_install() {
    apt-get install -y --no-install-recommends "$@"
}

upsert_boot_config() {
    file="$1"
    key="$2"
    val="$3"
    touch "$file"
    if grep -E -q "^[[:space:]]*$key=" "$file"; then
        sed -i "s/^[[:space:]]*$key=.*/$key=$val/" "$file"
    elif grep -E -q "^[[:space:]]*#[[:space:]]*$key=" "$file"; then
        sed -i "s/^[[:space:]]*#[[:space:]]*$key=.*/$key=$val/" "$file"
    else
        echo "$key=$val" >> "$file"
    fi
}

set_cmdline_arg() {
    file="$1"
    key="$2"
    value="$3"
    [ -f "$file" ] || return 0

    awk -v k="$key" -v v="$value" '
    {
        found = 0
        for (i=1; i<=NF; i++) {
            if ($i ~ "^" k "=") {
                $i = k "=" v
                found = 1
            }
        }
        if (!found) {
            $0 = $0 ? $0 " " k "=" v : k "=" v
        }
        print $0
    }
    END {
        if (NR == 0) print k "=" v
    }' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

set_cmdline_flag() {
    file="$1"
    flag="$2"
    [ -f "$file" ] || return 0

    awk -v f="$flag" '
    {
        found = 0
        for (i=1; i<=NF; i++) {
            if ($i == f) {
                found = 1
            }
        }
        if (!found) {
            $0 = $0 ? $0 " " f : f
        }
        print $0
    }
    END {
        if (NR == 0) print f
    }' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

set_sshd_kv() {
    file="$1"
    key="$2"
    value="$3"
    touch "$file"
    sed -i "/^[[:space:]]*#*[[:space:]]*$key[[:space:]]/d" "$file"
    printf '%s %s\n' "$key" "$value" >> "$file"
}

set_eq_kv() {
    file="$1"
    key="$2"
    value="$3"
    touch "$file"
    sed -i "/^[[:space:]]*#*[[:space:]]*$key=/d" "$file"
    printf '%s=%s\n' "$key" "$value" >> "$file"
}

validate_zerotier_network_id() {
    [ -n "$1" ] || return 1
    printf '%s' "$1" | grep -Eq '^[0-9a-fA-F]{16}$'
}

print_banner() {
    printf "%b\n" "$ORANGE"
    printf "        __      ___     _ _                 \n"
    printf "        \\ \\    / (_)   | | |                \n"
    printf "         \\ \\  / / _  __| | |     ___   ___  _ __  \n"
    printf "          \\ \\/ / | |/ _\` | |    / _ \\ / _ \\| '_ \\ \n"
    printf "           \\  /  | | (_| | |___| (_) | (_) | |_) |\n"
    printf "            \\/   |_|\\__,_|______\\___/ \\___/| .__/ \n"
    printf "                                            | |    \n"
    printf "                                            |_|    \n"
    printf "%b" "$WHITE"
    printf "        VIDLOOP 2.0 installer %s\n" "$SCRIPT_VERSION"
    printf "%b        Ignace - Powered by 44 Contenidos%b\n\n" "$DIM" "$WHITE"
}

print_banner

require_cmd awk
require_cmd sed
require_cmd grep
require_cmd find
require_cmd sort
require_cmd mktemp

if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    log_ok "Raspberry Pi detectada"
else
    log_warn "No se detecto Raspberry Pi. Se continua para permitir pruebas o imagenes custom."
fi

log_info "Actualizando indice APT..."
if ! apt_update; then
    log_error "apt-get update fallo. Verifica internet/DNS/repositorios."
    exit 1
fi
log_ok "APT actualizado"

if is_true "$VIDLOOP_FULL_UPGRADE"; then
    log_info "Ejecutando full-upgrade..."
    apt-get full-upgrade -y || log_warn "full-upgrade fallo; se continua con instalacion base."
fi

log_info "Instalando dependencias base..."
apt_install \
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    procps \
    psmisc \
    openssh-server \
    fbset \
    fbi

# Paquetes legacy de Raspberry (pueden faltar en versiones recientes como Bookworm+)
apt_install libraspberrypi-bin omxplayer >/dev/null 2>&1 || log_warn "omxplayer o libraspberrypi-bin no estan disponibles en esta version."
log_ok "Dependencias instaladas"

log_info "Instalando extractor de YouTube (yt-dlp)..."
apt_install python3 >/dev/null 2>&1 || true
if curl -sSLf https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp || wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp; then
    chmod a+rx /usr/local/bin/yt-dlp
    log_ok "yt-dlp instalado con exito en /usr/local/bin"
else
    log_warn "Fallo la instalacion rapida de yt-dlp. Intentando instalar via python3-pip..."
    if apt_install python3-pip python3-setuptools >/dev/null 2>&1; then
        if pip3 install --help 2>/dev/null | grep -q -- "--break-system-packages"; then
            pip3 install --break-system-packages -U yt-dlp >/dev/null 2>&1 || log_warn "No se pudo instalar yt-dlp via pip3."
        else
            pip3 install -U yt-dlp >/dev/null 2>&1 || log_warn "No se pudo instalar yt-dlp via pip3."
        fi
        if command -v yt-dlp >/dev/null 2>&1; then
            log_ok "yt-dlp instalado exitosamente via pip3"
        fi
    else
        log_error "No se pudo instalar yt-dlp. El soporte de links de YouTube estara inactivo."
    fi
fi


log_info "Instalando archivos VIDLOOP..."
install -d -m 0755 /usr/local/bin
install -m 0755 "$SCRIPT_DIR/vidloop-player.sh" /usr/local/bin/vidloop-player.sh
install -d -m 0755 /etc/default
install -d -m 0755 /etc/vidloop
touch /var/log/vidloop44.log
chmod 0644 /var/log/vidloop44.log

cat > /etc/default/vidloop <<EOF
# VIDLOOP runtime configuration.
VIDLOOP_MEDIA_DIR="$VIDLOOP_MEDIA_DIR"
VIDLOOP_IMAGE_DURATION_SEC="$VIDLOOP_IMAGE_DURATION_SEC"
VIDLOOP_WAIT_SEC="$VIDLOOP_WAIT_SEC"
VIDLOOP_TTY="$VIDLOOP_TTY"
VIDLOOP_FB_DEVICE="/dev/fb0"
VIDLOOP_VIDEO_ASPECT_MODE="$VIDLOOP_VIDEO_ASPECT_MODE"
VIDLOOP_LOG_FILE="/var/log/vidloop44.log"
VIDLOOP_SINGLE_VIDEO_LOOP="true"
VIDLOOP_EMPTY_SLEEP_SEC="5"
VIDLOOP_BOOT_BLACK_DELAY_SEC="$VIDLOOP_BOOT_BLACK_DELAY_SEC"
EOF
log_ok "Configuracion en /etc/default/vidloop"

log_info "Configurando usuario $VIDLOOP_USER..."
if ! id "$VIDLOOP_USER" >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" "$VIDLOOP_USER"
    log_ok "Usuario $VIDLOOP_USER creado"
else
    log_info "Usuario $VIDLOOP_USER ya existe"
fi

if ! getent group "$VIDLOOP_USER" >/dev/null 2>&1; then
    groupadd "$VIDLOOP_USER"
    log_ok "Grupo $VIDLOOP_USER creado"
fi

echo "$VIDLOOP_USER:$VIDLOOP_PASSWORD" | chpasswd
usermod -aG sudo,video,audio "$VIDLOOP_USER" 2>/dev/null || usermod -aG sudo "$VIDLOOP_USER" 2>/dev/null || true
usermod -aG "$VIDLOOP_USER" "$VIDLOOP_USER" 2>/dev/null || true
mkdir -p "$VIDLOOP_MEDIA_DIR"
chown -R "$VIDLOOP_USER:$VIDLOOP_USER" "$VIDLOOP_MEDIA_DIR"
chmod 0775 "$VIDLOOP_MEDIA_DIR"

if id pi >/dev/null 2>&1; then
    usermod -aG "$VIDLOOP_USER" pi 2>/dev/null || true
    if [ ! -e /home/pi/VIDLOOP44 ]; then
        ln -s "$VIDLOOP_MEDIA_DIR" /home/pi/VIDLOOP44 2>/dev/null || true
    fi
fi
log_ok "Usuario y carpeta de medios listos"

if [ -n "$VIDLOOP_LOGO_PATH" ] && [ -f "$VIDLOOP_LOGO_PATH" ]; then
    log_info "Instalando logo de arranque..."
    cp "$VIDLOOP_LOGO_PATH" /etc/vidloop/logo.png
    chmod 0644 /etc/vidloop/logo.png
    log_ok "Logo de arranque instalado"
fi

log_info "Configurando blackout visual de arranque..."
cat > /usr/local/bin/vidloop-boot-blackout.sh <<'EOF'
#!/bin/sh
CONFIG_FILE="/etc/default/vidloop"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

TTY="${VIDLOOP_TTY:-1}"
TTY_DEVICE="/dev/tty$TTY"
DELAY_SEC="${VIDLOOP_BOOT_BLACK_DELAY_SEC:-2}"

if command -v chvt >/dev/null 2>&1; then
    chvt "$TTY" >/dev/null 2>&1 || true
fi

if [ -w "$TTY_DEVICE" ]; then
    printf '\033c\033[?25l\033[40m\033[37m' > "$TTY_DEVICE" 2>/dev/null || true
fi

if command -v setterm >/dev/null 2>&1 && [ -w "$TTY_DEVICE" ]; then
    setterm -blank 0 -powerdown 0 -powersave off -cursor off -clear all > "$TTY_DEVICE" 2>/dev/null || true
fi

# Mostrar el logo si existe
if [ -f /etc/vidloop/logo.png ] && command -v fbi >/dev/null 2>&1; then
    fbi -T "$TTY" -d /dev/fb0 -noverbose -a /etc/vidloop/logo.png >/dev/null 2>&1 &
fi

case "$DELAY_SEC" in
    ''|*[!0-9]*) DELAY_SEC=2 ;;
esac
if [ "$DELAY_SEC" -gt 0 ]; then
    sleep "$DELAY_SEC"
fi

exit 0
EOF
chmod 0755 /usr/local/bin/vidloop-boot-blackout.sh

cat > /etc/systemd/system/vidloop-boot-blackout.service <<'EOF'
[Unit]
Description=VIDLOOP black screen before player starts
DefaultDependencies=no
After=local-fs.target
Before=basic.target getty.target video_looper.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vidloop-boot-blackout.sh
StandardOutput=null
StandardError=null

[Install]
WantedBy=sysinit.target
EOF
systemctl daemon-reload
systemctl enable vidloop-boot-blackout.service
log_ok "Blackout de arranque instalado"

log_info "Configurando servicio systemd video_looper..."
cat > /etc/systemd/system/video_looper.service <<EOF
[Unit]
Description=VIDLOOP mixed image/video looper
After=multi-user.target vidloop-boot-blackout.service
Wants=multi-user.target vidloop-boot-blackout.service

[Service]
Type=simple
EnvironmentFile=-/etc/default/vidloop
ExecStartPre=/usr/local/bin/vidloop-boot-blackout.sh
ExecStart=/usr/local/bin/vidloop-player.sh
Restart=always
RestartSec=3
User=root
Group=root
TTYPath=/dev/tty${VIDLOOP_TTY}
StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYReset=yes
TTYVHangup=yes
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/logrotate.d/vidloop <<'EOF'
/var/log/vidloop44.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    copytruncate
}
EOF

systemctl daemon-reload
systemctl enable video_looper
log_ok "Servicio video_looper instalado"

log_info "Configurando HDMI y consola..."
BOOT_CONFIG="/boot/config.txt"
[ -f "$BOOT_CONFIG" ] || BOOT_CONFIG="/boot/firmware/config.txt"
if [ -f "$BOOT_CONFIG" ]; then
    backup_once "$BOOT_CONFIG"
    upsert_boot_config "$BOOT_CONFIG" "hdmi_force_hotplug" "1"
    upsert_boot_config "$BOOT_CONFIG" "hdmi_drive" "2"
    upsert_boot_config "$BOOT_CONFIG" "hdmi_group" "$VIDLOOP_HDMI_GROUP"
    upsert_boot_config "$BOOT_CONFIG" "hdmi_mode" "$VIDLOOP_HDMI_MODE"
    upsert_boot_config "$BOOT_CONFIG" "config_hdmi_boost" "$VIDLOOP_HDMI_BOOST"
    upsert_boot_config "$BOOT_CONFIG" "hdmi_blanking" "0"
    upsert_boot_config "$BOOT_CONFIG" "hdmi_ignore_cec_init" "1"
    upsert_boot_config "$BOOT_CONFIG" "disable_overscan" "1"
    upsert_boot_config "$BOOT_CONFIG" "disable_splash" "1"
    upsert_boot_config "$BOOT_CONFIG" "gpu_mem" "128"
    if is_true "$VIDLOOP_HDMI_IGNORE_EDID"; then
        upsert_boot_config "$BOOT_CONFIG" "hdmi_ignore_edid" "0xa5000080"
        log_warn "HDMI ignore EDID activado. Usalo solo si la pantalla no entrega EDID confiable."
    else
        sed -i "/^[[:space:]]*#*[[:space:]]*hdmi_ignore_edid=/d" "$BOOT_CONFIG" 2>/dev/null || true
    fi
    log_ok "HDMI configurado en $BOOT_CONFIG"
else
    log_warn "No se encontro config.txt de boot"
fi

CMDLINE_TXT=""
if [ -f /boot/cmdline.txt ]; then
    CMDLINE_TXT="/boot/cmdline.txt"
elif [ -f /boot/firmware/cmdline.txt ]; then
    CMDLINE_TXT="/boot/firmware/cmdline.txt"
fi

if [ -n "$CMDLINE_TXT" ]; then
    backup_once "$CMDLINE_TXT"
    set_cmdline_arg "$CMDLINE_TXT" consoleblank 0
    set_cmdline_arg "$CMDLINE_TXT" vt.global_cursor_default 0
    if is_true "$VIDLOOP_QUIET_BOOT"; then
        set_cmdline_flag "$CMDLINE_TXT" quiet
        set_cmdline_flag "$CMDLINE_TXT" splash
        set_cmdline_flag "$CMDLINE_TXT" logo.nologo
        set_cmdline_arg "$CMDLINE_TXT" loglevel 0
        set_cmdline_arg "$CMDLINE_TXT" systemd.show_status false
        set_cmdline_arg "$CMDLINE_TXT" rd.systemd.show_status false
        set_cmdline_arg "$CMDLINE_TXT" udev.log_priority 3
    fi
    log_ok "Console blanking desactivado"
else
    log_warn "No se encontro cmdline.txt"
fi

if [ -f /etc/kbd/config ]; then
    backup_once /etc/kbd/config
    set_eq_kv /etc/kbd/config "BLANK_TIME" "0"
    set_eq_kv /etc/kbd/config "POWERDOWN_TIME" "0"
    log_ok "Blanking de consola desactivado en /etc/kbd/config"
fi

log_info "Instalando guardia anti-blanking de consola..."
cat > /usr/local/bin/vidloop-display-guard.sh <<'EOF'
#!/bin/sh
CONFIG_FILE="/etc/default/vidloop"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

TTY="${VIDLOOP_TTY:-1}"
TTY_DEVICE="/dev/tty$TTY"

apply_display_guard() {
    if command -v setterm >/dev/null 2>&1 && [ -w "$TTY_DEVICE" ]; then
        setterm -blank 0 -powerdown 0 -powersave off -cursor off > "$TTY_DEVICE" 2>/dev/null || true
        printf '\033[?25l' > "$TTY_DEVICE" 2>/dev/null || true
    fi

    if [ -w /sys/class/graphics/fbcon/cursor_blink ]; then
        printf '0' > /sys/class/graphics/fbcon/cursor_blink 2>/dev/null || true
    fi
}

apply_display_guard
while true; do
    apply_display_guard
    sleep 30
done
EOF
chmod 0755 /usr/local/bin/vidloop-display-guard.sh

cat > /etc/systemd/system/vidloop-display-guard.service <<'EOF'
[Unit]
Description=VIDLOOP display anti-blanking guard
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/vidloop-display-guard.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable vidloop-display-guard.service
log_ok "Guardia anti-blanking instalado"

if is_true "$VIDLOOP_DISABLE_TTY_GETTY"; then
    systemctl disable --now "getty@tty${VIDLOOP_TTY}.service" 2>/dev/null || true
    log_ok "getty@tty${VIDLOOP_TTY} desactivado para evitar login prompt sobre el loop"
fi

if is_true "$VIDLOOP_ENABLE_HDMI_KEEPALIVE" && command -v tvservice >/dev/null 2>&1; then
    log_info "Instalando HDMI keepalive (tvservice daemon)..."
    cat > /usr/local/bin/vidloop-hdmi-keepalive.sh <<'EOF'
#!/bin/sh
CONFIG_FILE="/etc/default/vidloop"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

TTY="${VIDLOOP_TTY:-1}"
STATE_FILE="/run/vidloop-hdmi-keepalive.state"

log_msg() {
    logger -t vidloop-hdmi-keepalive "$*"
}

refresh_framebuffer() {
    if command -v fbset >/dev/null 2>&1; then
        current_depth="$(fbset 2>/dev/null | awk '/geometry/ {print $6; exit}')"
        [ -n "$current_depth" ] || current_depth="16"
        fbset -depth 8 >/dev/null 2>&1 || true
        sleep 1
        fbset -depth "$current_depth" >/dev/null 2>&1 || true
    fi

    chvt 6 >/dev/null 2>&1 || true
    sleep 1
    chvt "$TTY" >/dev/null 2>&1 || true
}

while true; do
    if command -v tvservice >/dev/null 2>&1; then
        status="$(tvservice -s 2>/dev/null || true)"
        if printf '%s' "$status" | grep -Eiq "TV is off|No device|HDMI.*off"; then
            if ! [ -f "$STATE_FILE" ] || ! grep -q '^off$' "$STATE_FILE" 2>/dev/null; then
                log_msg "HDMI sin senal detectado: $status"
                printf 'off' > "$STATE_FILE" 2>/dev/null || true
                systemctl try-restart video_looper.service >/dev/null 2>&1 || true
            fi
            tvservice -p >/dev/null 2>&1 || true
            refresh_framebuffer
        elif [ -f "$STATE_FILE" ] && grep -q '^off$' "$STATE_FILE" 2>/dev/null; then
            log_msg "HDMI recuperado: $status"
            printf 'on' > "$STATE_FILE" 2>/dev/null || true
            tvservice -p >/dev/null 2>&1 || true
            refresh_framebuffer
            systemctl try-restart video_looper.service >/dev/null 2>&1 || true
        else
            if command -v setterm >/dev/null 2>&1 && [ -w "/dev/tty$TTY" ]; then
                setterm -blank 0 -powerdown 0 -powersave off -cursor off > "/dev/tty$TTY" 2>/dev/null || true
            fi
        fi
    fi
    sleep 10
done
EOF
    chmod 0755 /usr/local/bin/vidloop-hdmi-keepalive.sh
    cat > /etc/systemd/system/vidloop-hdmi-keepalive.service <<'EOF'
[Unit]
Description=VIDLOOP HDMI keepalive
After=multi-user.target vidloop-boot-blackout.service vidloop-display-guard.service
Wants=vidloop-boot-blackout.service vidloop-display-guard.service

[Service]
Type=simple
ExecStart=/usr/local/bin/vidloop-hdmi-keepalive.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable vidloop-hdmi-keepalive.service
    log_ok "HDMI keepalive instalado"
fi

log_info "Configurando SSH..."
systemctl enable ssh 2>/dev/null || true
backup_once /etc/ssh/sshd_config
if is_true "$ENABLE_SSH_PASSWORD_AUTH"; then
    set_sshd_kv /etc/ssh/sshd_config PasswordAuthentication yes
    set_sshd_kv /etc/ssh/sshd_config KbdInteractiveAuthentication yes
else
    set_sshd_kv /etc/ssh/sshd_config PasswordAuthentication no
    set_sshd_kv /etc/ssh/sshd_config KbdInteractiveAuthentication no
fi
set_sshd_kv /etc/ssh/sshd_config PubkeyAuthentication yes
set_sshd_kv /etc/ssh/sshd_config PermitRootLogin no
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
log_ok "SSH configurado"

log_info "Instalando ZeroTier..."
if command -v zerotier-one >/dev/null 2>&1; then
    log_ok "ZeroTier ya esta instalado"
elif apt-get install -y zerotier-one 2>/dev/null; then
    log_ok "ZeroTier instalado por APT"
else
    log_info "Instalando ZeroTier con script oficial..."
    curl -fsSL https://install.zerotier.com | bash
fi

if command -v zerotier-one >/dev/null 2>&1; then
    systemctl enable --now zerotier-one 2>/dev/null || true
    sleep 2
    log_ok "ZeroTier activo"
else
    log_warn "ZeroTier no quedo instalado. Revisa conectividad o repositorios."
fi

if [ -n "$VIDLOOP_ZT_NETWORK_ID" ]; then
    if validate_zerotier_network_id "$VIDLOOP_ZT_NETWORK_ID"; then
        log_info "Uniendo a ZeroTier network $VIDLOOP_ZT_NETWORK_ID..."
        zerotier-cli join "$VIDLOOP_ZT_NETWORK_ID" || log_warn "No se pudo ejecutar zerotier-cli join"
        ZT_NODE_ID="$(zerotier-cli info 2>/dev/null | awk '{print $3}' || true)"
        log_ok "Join enviado. Node ID: ${ZT_NODE_ID:-desconocido}"
        log_warn "Autoriza este nodo en ZeroTier Central para que reciba IP administrada."
    else
        log_warn "VIDLOOP_ZT_NETWORK_ID invalido: $VIDLOOP_ZT_NETWORK_ID"
        log_warn "Debe tener 16 caracteres hexadecimales."
    fi
else
    log_warn "Sin network ZeroTier. Luego podes ejecutar: sudo zerotier-cli join <network-id>"
fi

log_info "Iniciando servicios..."
systemctl start vidloop-boot-blackout.service 2>/dev/null || true
systemctl restart video_looper.service || log_warn "No se pudo iniciar video_looper en este entorno"
systemctl start vidloop-display-guard.service 2>/dev/null || true
systemctl start vidloop-hdmi-keepalive.service 2>/dev/null || true

LAN_IP="$(ip -4 addr show 2>/dev/null | awk '/inet / && $2 !~ /^127\./ {gsub(/\/.*/, "", $2); print $2; exit}' || true)"
ZT_IP="$(ip -4 addr show 2>/dev/null | awk '/inet / && $2 ~ /^10\.|^172\.|^192\.168\./ {gsub(/\/.*/, "", $2); print $2}' | tail -1 || true)"

printf "\n%b==============================================%b\n" "$GREEN" "$NC"
printf "%b      VIDLOOP 2.0 instalado correctamente%b\n" "$GREEN" "$NC"
printf "%b==============================================%b\n" "$GREEN" "$NC"
printf "%bUsuario SSH:%b %s\n" "$YELLOW" "$NC" "$VIDLOOP_USER"
printf "%bPassword SSH:%b %s\n" "$YELLOW" "$NC" "$VIDLOOP_PASSWORD"
printf "%bCarpeta medios:%b %s\n" "$YELLOW" "$NC" "$VIDLOOP_MEDIA_DIR"
printf "%bServicio:%b video_looper\n" "$YELLOW" "$NC"
printf "%bLog:%b /var/log/vidloop44.log\n" "$YELLOW" "$NC"
[ -n "$LAN_IP" ] && printf "%bIP detectada:%b %s\n" "$YELLOW" "$NC" "$LAN_IP"
[ -n "$ZT_IP" ] && printf "%bIP candidata ZeroTier/LAN:%b %s\n" "$YELLOW" "$NC" "$ZT_IP"
printf "\nComandos utiles:\n"
printf "  sudo systemctl restart video_looper\n"
printf "  sudo journalctl -u video_looper -f\n"
printf "  sudo tail -f /var/log/vidloop44.log\n"
printf "  sudo zerotier-cli listnetworks\n"

if is_true "$VIDLOOP_AUTO_REBOOT"; then
    log_info "Reinicio automatico en 5 segundos..."
    sleep 5
    reboot
else
    log_warn "Reinicio pendiente recomendado: sudo reboot"
fi
