#!/usr/bin/env bash
set -euo pipefail

# ================================================================
#  VIDLOOP RPi BACKUP → VPS
#  Genera imagen comprimida de una RPi y la guarda en el VPS
#  Desarrollado por IGNACE — Powered by 44 Contenidos
# ================================================================
#
# USO:
#   ./backup-rpi-to-vps.sh <nombre> <host_rpi>
#   ./backup-rpi-to-vps.sh totem-lanser-1 192.168.1.10
#   ./backup-rpi-to-vps.sh totem-lanser-1 10.0.0.2         ← vía WireGuard
#
#   RPI_USER=pi RPI_PASS=raspberry ./backup-rpi-to-vps.sh rpi-01 192.168.1.5
#
# VARIABLES DE ENTORNO:
#   RPI_USER     Usuario SSH de la RPi                 (default: vidloop)
#   RPI_PASS     Password SSH de la RPi                (default: 4455)
#   RPI_PORT     Puerto SSH de la RPi                  (default: 22)
#   VPS_IP       IP del VPS destino                    (default: 82.25.77.55)
#   VPS_USER     Usuario SSH del VPS                   (default: root)
#   VPS_PASS     Password del VPS                      (default: Vidloop@44tech)
#   IMG_DIR      Directorio en VPS donde guardar imgs  (default: /opt/vidloop-dash/images)
#   KEEP_LAST    Cuántas imágenes conservar por RPi    (default: 3)
#   SD_DEV       Dispositivo SD en RPi                 (default: /dev/mmcblk0)
#   DRY_RUN      true = solo simular, no ejecutar      (default: false)
# ================================================================

# ── COLORES ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}  $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "\n${CYAN}══ $1 ══${NC}"; }

# ── PARÁMETROS ───────────────────────────────────────────────────
RPI_NAME="${1:-}"
RPI_HOST="${2:-}"

if [[ -z "$RPI_NAME" || -z "$RPI_HOST" ]]; then
    echo -e "${BOLD}USO:${NC} $0 <nombre> <host_rpi>"
    echo -e "  Ejemplo: $0 totem-lanser-1 192.168.1.10"
    exit 1
fi

# ── CONFIGURACIÓN ────────────────────────────────────────────────
RPI_USER="${RPI_USER:-vidloop}"
RPI_PASS="${RPI_PASS:-4455}"
RPI_PORT="${RPI_PORT:-22}"
VPS_IP="${VPS_IP:-82.25.77.55}"
VPS_USER="${VPS_USER:-root}"
VPS_PASS="${VPS_PASS:-Vidloop@44tech}"
IMG_DIR="${IMG_DIR:-/opt/vidloop-dash/images}"
KEEP_LAST="${KEEP_LAST:-3}"
SD_DEV="${SD_DEV:-/dev/mmcblk0}"
DRY_RUN="${DRY_RUN:-false}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
IMG_NAME="${RPI_NAME}_${TIMESTAMP}.img.gz"

# ── DEPENDENCIAS ─────────────────────────────────────────────────
check_deps() {
    for dep in sshpass ssh; do
        if ! command -v "$dep" &>/dev/null; then
            log_error "Falta dependencia: $dep"
            if [[ "$dep" == "sshpass" ]]; then
                echo "  Instalá con: brew install sshpass"
            fi
            exit 1
        fi
    done
}

# ── SSH HELPERS ──────────────────────────────────────────────────
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=15 -o ServerAliveInterval=30 -o ServerAliveCountMax=3"

rpi_ssh() {
    SSHPASS="$RPI_PASS" sshpass -e ssh $SSH_OPTS -p "$RPI_PORT" "${RPI_USER}@${RPI_HOST}" "$@"
}

vps_ssh() {
    SSHPASS="$VPS_PASS" sshpass -e ssh $SSH_OPTS "${VPS_USER}@${VPS_IP}" "$@"
}

# ── BANNER ───────────────────────────────────────────────────────
echo -e "\n${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║     VIDLOOP RPi BACKUP v1.0                  ║"
echo "  ║     Powered by 44 Contenidos — IGNACE        ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"

if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "DRY_RUN activado — no se ejecutará nada real"
fi

echo -e "  RPi  : ${BOLD}${RPI_NAME}${NC} (${RPI_HOST}:${RPI_PORT})"
echo -e "  VPS  : ${VPS_USER}@${VPS_IP}"
echo -e "  Dest : ${IMG_DIR}/${IMG_NAME}"
echo -e "  SD   : ${SD_DEV}"
echo ""

# ── PASO 1: VERIFICAR DEPENDENCIAS ───────────────────────────────
log_step "1/4 Verificando dependencias"
check_deps
log_ok "sshpass y ssh disponibles"

# ── PASO 2: VERIFICAR CONEXIÓN ───────────────────────────────────
log_step "2/4 Verificando conexión SSH"

log_info "Probando SSH a RPi ${RPI_HOST}..."
if [[ "$DRY_RUN" != "true" ]]; then
    if ! rpi_ssh "echo OK" &>/dev/null; then
        log_error "No se pudo conectar a la RPi ${RPI_HOST}:${RPI_PORT}"
        exit 1
    fi
    log_ok "RPi accesible"
fi

log_info "Probando SSH a VPS ${VPS_IP}..."
if [[ "$DRY_RUN" != "true" ]]; then
    if ! vps_ssh "echo OK" &>/dev/null; then
        log_error "No se pudo conectar al VPS ${VPS_IP}"
        exit 1
    fi
    log_ok "VPS accesible"

    # Crear directorio de imágenes en VPS si no existe
    vps_ssh "mkdir -p '${IMG_DIR}'"
fi

# ── PASO 3: OBTENER INFO DE LA SD ────────────────────────────────
log_step "3/4 Generando imagen"

if [[ "$DRY_RUN" != "true" ]]; then
    # Verificar que el dispositivo SD existe en la RPi
    if ! rpi_ssh "sudo test -b '${SD_DEV}'" 2>/dev/null; then
        log_error "El dispositivo ${SD_DEV} no existe en la RPi"
        log_warn "Si usás SD en slot diferente, exportá: SD_DEV=/dev/sda ./backup-rpi-to-vps.sh ..."
        exit 1
    fi

    # Obtener tamaño de la SD para mostrar progreso
    SD_SIZE=$(rpi_ssh "sudo blockdev --getsize64 '${SD_DEV}' 2>/dev/null || echo 0" 2>/dev/null || echo 0)
    if [[ "$SD_SIZE" -gt 0 ]]; then
        SD_SIZE_GB=$(awk "BEGIN {printf \"%.1f\", ${SD_SIZE}/1073741824}")
        log_info "Tamaño de SD: ${SD_SIZE_GB} GB"
    fi
fi

log_info "Iniciando dd + gzip | SSH pipe → VPS..."
log_info "Imagen destino: ${IMG_DIR}/${IMG_NAME}"
log_warn "Esto puede tardar entre 10 y 40 minutos según el tamaño de la SD"

if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "[DRY_RUN] Hubiera ejecutado el pipe dd → VPS"
else
    # Pipe directo: RPi --dd/gzip--> Mac --ssh--> VPS
    # La imagen NUNCA toca el disco de la Mac
    SSHPASS="$RPI_PASS" sshpass -e ssh $SSH_OPTS -p "$RPI_PORT" \
        "${RPI_USER}@${RPI_HOST}" \
        "sudo dd if=${SD_DEV} bs=4M status=progress 2>/dev/null | gzip -c" \
    | SSHPASS="$VPS_PASS" sshpass -e ssh $SSH_OPTS \
        "${VPS_USER}@${VPS_IP}" \
        "cat > '${IMG_DIR}/${IMG_NAME}'"

    log_ok "Imagen guardada: ${IMG_DIR}/${IMG_NAME}"
fi

# ── PASO 4: LIMPIEZA DE IMÁGENES VIEJAS ──────────────────────────
log_step "4/4 Limpieza (conservar últimas ${KEEP_LAST} por RPi)"

if [[ "$DRY_RUN" != "true" ]]; then
    # Lista imágenes de esta RPi ordenadas por fecha, borra las más viejas
    vps_ssh "
        imgs=(\$(ls -t '${IMG_DIR}/${RPI_NAME}'_*.img.gz 2>/dev/null))
        total=\${#imgs[@]}
        keep=${KEEP_LAST}
        if [[ \$total -gt \$keep ]]; then
            to_delete=(\"\${imgs[@]:\$keep}\")
            for f in \"\${to_delete[@]}\"; do
                echo \"Eliminando: \$f\"
                rm -f \"\$f\"
            done
            echo \"Conservadas: \$keep de \$total imágenes\"
        else
            echo \"Imágenes de ${RPI_NAME}: \$total (dentro del límite \$keep)\"
        fi
    "

    # Mostrar todas las imágenes disponibles en VPS
    echo ""
    log_info "Imágenes disponibles en VPS:"
    vps_ssh "ls -lh '${IMG_DIR}/${RPI_NAME}'_*.img.gz 2>/dev/null || echo '  (ninguna encontrada)'"
else
    log_warn "[DRY_RUN] Hubiera limpiado imágenes viejas de ${RPI_NAME} en VPS"
fi

# ── FIN ──────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✓ Backup completado${NC}"
echo -e "  Imagen: ${BOLD}${IMG_DIR}/${IMG_NAME}${NC}"
echo ""
echo -e "${CYAN}Para descargar la imagen a tu PC:${NC}"
echo -e "  scp ${VPS_USER}@${VPS_IP}:${IMG_DIR}/${IMG_NAME} ."
echo -e "  Luego descomprimila con 7-Zip y flasheala con Balena Etcher"
echo ""
