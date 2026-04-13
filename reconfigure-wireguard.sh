#!/usr/bin/env bash
set -euo pipefail

# ================================================================
#          RECONFIGURE WIREGUARD - VIDLOOP V3.0
#   Script para reconfigurar WireGuard en RPi sin reinstalar todo
# ================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validaciones iniciales
if [ $# -eq 0 ]; then
    log_error "Uso: $0 <ruta-a-wg0.conf>"
    log_info "Ejemplo: $0 /home/mi-usuario/wg0.conf"
    log_info "O remotamente:"
    log_info "  WG_B64=\$(base64 -w0 wg0.conf | tr -d '\n')"
    log_info "  ssh vidloop@10.8.0.3 'bash' < reconfigure-wireguard.sh \$WG_B64"
    exit 1
fi

WG_CONF_SOURCE="$1"
WG_INTERFACE="${2:-wg0}"
WG_PATH="/etc/wireguard/${WG_INTERFACE}.conf"

log_info "=================================================="
log_info "  REKONFIGURACI\u00d3N DE WIREGUARD - VIDLOOP V3.0"
log_info "=================================================="
log_info "Interfaz: ${WG_INTERFACE}"
log_info "Ruta: ${WG_PATH}"
echo

# Verificar que tenemos permisos sudo
if ! sudo -n true 2>/dev/null; then
    log_error "Se requieren permisos sudo sin password"
    exit 1
fi

# Manejar entrada base64 o archivo
if [ -f "$WG_CONF_SOURCE" ]; then
    log_info "Usando archivo: $WG_CONF_SOURCE"
    WG_CONFIG_FILE="$WG_CONF_SOURCE"
elif [[ "$WG_CONF_SOURCE" =~ ^[A-Za-z0-9+/=]+$ ]]; then
    log_info "Descodificando contenido base64..."
    if echo "$WG_CONF_SOURCE" | base64 -d > /tmp/wg0_decoded.conf 2>/dev/null; then
        WG_CONFIG_FILE="/tmp/wg0_decoded.conf"
        log_ok "Contenido base64 descodificado"
    else
        log_error "No se pudo descodificar base64"
        exit 1
    fi
else
    log_error "Argumento inválido. Debe ser ruta a archivo o string base64"
    exit 1
fi

# Validar que el archivo tiene contenido
if [ ! -f "$WG_CONFIG_FILE" ] || [ ! -s "$WG_CONFIG_FILE" ]; then
    log_error "Archivo wg0.conf vacío o no existe"
    exit 1
fi

# Verificar que el archivo tiene estructura básica de WireGuard
if ! grep -q "^\[Interface\]" "$WG_CONFIG_FILE"; then
    log_error "Archivo no parece ser un wg0.conf válido (falta [Interface])"
    exit 1
fi

log_ok "Archivo WireGuard válido"
echo

# Detener interfaz si está activa
log_info "Deteniendo WireGuard si está activo..."
if sudo systemctl is-active "wg-quick@${WG_INTERFACE}" >/dev/null 2>&1; then
    sudo systemctl stop "wg-quick@${WG_INTERFACE}" 2>/dev/null || true
    log_ok "Interfaz detenida"
else
    log_info "Interfaz no está activa"
fi

# Hacer backup de configuración anterior
if [ -f "$WG_PATH" ]; then
    BACKUP_PATH="${WG_PATH}.backup.$(date +%s)"
    log_info "Backup de configuración anterior: $BACKUP_PATH"
    sudo cp "$WG_PATH" "$BACKUP_PATH"
fi

# Instalar WireGuard si no existe
log_info "Verificando WireGuard..."
if ! command -v wg >/dev/null 2>&1; then
    log_warn "WireGuard no instalado, instalando..."
    sudo apt-get update -o Acquire::Check-Valid-Until=false >/dev/null 2>&1
    sudo apt-get install -y wireguard wireguard-tools >/dev/null 2>&1
    log_ok "WireGuard instalado"
else
    log_ok "WireGuard ya instalado"
fi

# Copiar nueva configuración
log_info "Aplicando nueva configuración de WireGuard..."
sudo install -m 0600 "$WG_CONFIG_FILE" "$WG_PATH"
log_ok "Configuración copiada a $WG_PATH"

# Iniciar interfaz
log_info "Iniciando interfaz ${WG_INTERFACE}..."
if sudo systemctl enable --now "wg-quick@${WG_INTERFACE}" 2>/dev/null; then
    sleep 2
    if ip link show "${WG_INTERFACE}" >/dev/null 2>&1; then
        log_ok "WireGuard interfaz ${WG_INTERFACE} ACTIVA"
    else
        log_warn "Interfaz iniciada pero no aparece en 'ip link'"
    fi
else
    log_error "No se pudo activar WireGuard"
    exit 1
fi

# Mostrar status
echo
log_info "Status de WireGuard:"
echo "---"
sudo wg show "${WG_INTERFACE}" 2>/dev/null || log_warn "No se pudo obtener status con 'wg show'"
echo "---"

# Probar conectividad
echo
log_info "Probando conectividad..."
PRIVATE_IP=$(grep -A2 "^\[Interface\]" "$WG_CONFIG_FILE" | grep "^Address" | head -1 | awk '{print $3}' | cut -d/ -f1)

if [ -n "$PRIVATE_IP" ]; then
    log_info "IP privada configurada: $PRIVATE_IP"
    if ping -c 1 "$PRIVATE_IP" >/dev/null 2>&1; then
        log_ok "Loopback a IP privada OK"
    else
        log_warn "No se puede hacer ping a loopback (esperado en algunas configs)"
    fi
fi

# Verificar que video_looper todavía funciona
echo
log_info "Verificando video_looper..."
if sudo systemctl is-active video_looper >/dev/null 2>&1; then
    log_ok "video_looper sigue activo"
else
    log_warn "video_looper no está activo, intentando reiniciar..."
    sudo systemctl restart video_looper >/dev/null 2>&1 || log_warn "No se pudo reiniciar video_looper"
fi

echo
echo -e "${GREEN}=================================================="
echo -e "     RECONFIGURACIÓN COMPLETADA"
echo -e "==================================================${NC}"
log_info "WireGuard interface: ${WG_INTERFACE}"
log_info "Config: ${WG_PATH}"

if [ -f /tmp/wg0_decoded.conf ]; then
    rm -f /tmp/wg0_decoded.conf
fi

log_ok "Ahora puedes acceder al dashboard a través de la VPN"
