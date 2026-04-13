#!/usr/bin/env bash
set -euo pipefail

# ================================================================
#     WIREGUARD PEER GENERATOR - TOTEM LANSER 2
#  Script para generar configuración de cliente en servidor VPS
# ================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  WIREGUARD PEER GENERATOR - TOTEM LANSER 2${NC}"
echo -e "${BLUE}================================================${NC}"
echo

# Verificaciones iniciales
if [ "$EUID" -ne 0 ]; then 
    log_error "Este script requiere permisos root (usa: sudo bash $0)"
    exit 1
fi

if ! command -v wg >/dev/null 2>&1; then
    log_error "WireGuard no está instalado"
    log_info "Instala: apt-get update && apt-get install -y wireguard wireguard-tools"
    exit 1
fi

# Determinar interfaz y parámetros
WG_INTERFACE="${WG_INTERFACE:-wg0}"
TOTEM_IP="${TOTEM_IP:-10.0.0.2}"
TOTEM_NAME="${TOTEM_NAME:-totem_lanser_2}"

log_info "Interfaz WireGuard: $WG_INTERFACE"
log_info "IP privada TOTEM: $TOTEM_IP"
log_info "Nombre del peer: $TOTEM_NAME"
echo

# Verificar que la interfaz existe
if ! ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
    log_error "Interfaz $WG_INTERFACE no existe en VPS"
    log_info "Interfaces disponibles:"
    ip link show | grep "^[0-9]"
    exit 1
fi

log_ok "Interfaz $WG_INTERFACE encontrada"
echo

# ================================================================
# PASO 1: Generar claves para TOTEM
# ================================================================
log_info "Generando par de claves para TOTEM..."

WORK_DIR="/tmp/wireguard-totem-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Generar claves
wg genkey | tee totem_private.key | wg pubkey > totem_public.key

TOTEM_PRIVKEY=$(cat totem_private.key)
TOTEM_PUBKEY=$(cat totem_public.key)

log_ok "Claves generadas"
echo "  Clave privada TOTEM (primer 32 chars): ${TOTEM_PRIVKEY:0:32}..."
echo "  Clave pública TOTEM: $TOTEM_PUBKEY"
echo

# ================================================================
# PASO 2: Obtener datos del servidor VPS
# ================================================================
log_info "Obteniendo configuración del servidor VPS..."

VPS_PUBKEY=$(wg pubkey < <(wg genkey) 2>/dev/null || true)
if [ -z "$VPS_PUBKEY" ]; then
    # Alternativa: obtener del archivo de configuración existente
    VPS_CONFIG="/etc/wireguard/${WG_INTERFACE}.conf"
    if [ -f "$VPS_CONFIG" ]; then
        VPS_PUBKEY=$(grep -A1 "^\[Interface\]" "$VPS_CONFIG" 2>/dev/null | grep "PrivateKey" | awk '{print $3}' | wg pubkey)
    else
        log_warn "No se pudo obtener clave pública del servidor automáticamente"
        log_info "Ejecuta manualmente: wg pubkey < /ruta/a/server-privatekey.key"
        read -p "Ingresa la clave pública del servidor: " VPS_PUBKEY
    fi
fi

# Obtener puerto y endpoint
WG_PORT=$(wg show "$WG_INTERFACE" listen-port)
SERVER_IP="82.25.77.55"
ENDPOINT="${SERVER_IP}:${WG_PORT}"

log_ok "Clave pública VPS: ${VPS_PUBKEY:0:32}..."
log_ok "Endpoint: $ENDPOINT"
echo

# ================================================================
# PASO 3: Obtener rango de red privada
# ================================================================
log_info "Detectando rango de red privada..."

NETWORK=$(ip addr show "$WG_INTERFACE" | grep "inet " | awk '{print $2}' | head -1)
if [ -z "$NETWORK" ]; then
    NETWORK="10.0.0.0/24"
    log_warn "No se detectó red, usando default: $NETWORK"
else
    log_ok "Red detectada: $NETWORK"
fi

echo

# ================================================================
# PASO 4: Crear wg0.conf para TOTEM
# ================================================================
log_info "Generando wg0.conf para TOTEM..."

cat > wg0.conf << WGEOF
[Interface]
PrivateKey = $TOTEM_PRIVKEY
Address = $TOTEM_IP/24
DNS = 8.8.8.8, 8.8.4.4
ListenPort = 51820

[Peer]
PublicKey = $VPS_PUBKEY
Endpoint = $ENDPOINT
AllowedIPs = $NETWORK
PersistentKeepalive = 25
WGEOF

log_ok "Archivo wg0.conf creado"
echo

# ================================================================
# PASO 5: Agregar peer en servidor
# ================================================================
log_info "Agregando TOTEM como peer en VPS ($WG_INTERFACE)..."

# Verificar si ya existe el peer
EXISTING=$(wg show "$WG_INTERFACE" peers | grep "$TOTEM_PUBKEY" || true)
if [ -n "$EXISTING" ]; then
    log_warn "Peer ya existe, actualizando..."
    wg set "$WG_INTERFACE" peer "$TOTEM_PUBKEY" allowed-ips "$TOTEM_IP/32"
else
    wg set "$WG_INTERFACE" peer "$TOTEM_PUBKEY" allowed-ips "$TOTEM_IP/32"
    log_ok "Peer agregado"
fi

# Persistir cambios
if systemctl is-active --quiet "wg-quick@${WG_INTERFACE}"; then
    log_info "Actualizando configuración persistente..."
    wg-quick save "$WG_INTERFACE" 2>/dev/null || true
fi

echo

# ================================================================
# PASO 6: Mostrar información de transferencia
# ================================================================
log_info "Información para transferir a TOTEM:"
echo
echo "Archivo generado: $WORK_DIR/wg0.conf"
echo
echo "═══════════════════════════════════════════════════════════"
echo "OPCIÓN A: Descargar via SCP desde tu máquina local"
echo "═══════════════════════════════════════════════════════════"
echo
echo "scp root@82.25.77.55:$WORK_DIR/wg0.conf ./"
echo "# Luego en RPi:"
echo "scp wg0.conf vidloop@192.168.0.53:~/"
echo
echo "═══════════════════════════════════════════════════════════"
echo "OPCIÓN B: O desde RPi, conectarse directamente a VPS"
echo "═══════════════════════════════════════════════════════════"
echo
echo "scp root@82.25.77.55:$WORK_DIR/wg0.conf ~/"
echo
echo "═══════════════════════════════════════════════════════════"
echo "USAR EL ARCHIVO EN TOTEM"
echo "═══════════════════════════════════════════════════════════"
echo
echo "cd ~/VIDLOOP-main"
echo "git pull 2>/dev/null || ("
echo "  curl -fL https://github.com/ignacentenox/VIDLOOP/archive/refs/heads/main.zip -o VIDLOOP.zip"
echo "  unzip -q VIDLOOP.zip"
echo "  cp VIDLOOP-main/reconfigure-wireguard.sh ."
echo ")"
echo
echo "chmod +x reconfigure-wireguard.sh"
echo "./reconfigure-wireguard.sh ~/wg0.conf"
echo
echo "═══════════════════════════════════════════════════════════"
echo

# ================================================================
# PASO 7: Mostrar verificación
# ================================================================
log_info "Estado actual de WireGuard en VPS:"
echo
wg show "$WG_INTERFACE" peers
echo
log_ok "Configuración completada"
echo
log_info "Para limpiar temporales después (en VPS): rm -rf $WORK_DIR"
echo

# Guardar ruta para acceso fácil
echo "$WORK_DIR" > /tmp/wireguard-totem-path
log_ok "Ruta guardada en /tmp/wireguard-totem-path"
