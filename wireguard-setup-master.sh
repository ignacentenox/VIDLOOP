#!/bin/bash

################################################################################
# WIREGUARD-SETUP-MASTER.sh
# 
# Script maestro que configura WireGuard COMPLETAMENTE de forma automatizada.
# - Descarga wg0.conf desde VPS
# - Transfiere a RPi  
# - Aplica configuración con TOTEM-WG-SETUP.sh
# - Verifica conectividad
#
# PREREQUISITO: wg0.conf debe existir en VPS (generar con generate-wg-peer.sh primero)
#
# USO: 
#   ./wireguard-setup-master.sh [VPS_IP] [VPS_USER] [VPS_PASS] [RPI_IP] [RPI_USER] [RPI_PASS]
#
# EJEMPLO:
#   ./wireguard-setup-master.sh 82.25.77.55 root Vidloop@44tech 192.168.0.53 vidloop 4455
#
################################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parámetros con defaults
VPS_IP="${1:-82.25.77.55}"
VPS_USER="${2:-root}"
VPS_PASS="${3:-Vidloop@44tech}"
RPI_IP="${4:-192.168.0.53}"
RPI_USER="${5:-vidloop}"
RPI_PASS="${6:-4455}"

WORK_DIR="/tmp/wg-setup-$$"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"
REPO_URL="https://raw.githubusercontent.com/ignacentenox/VIDLOOP/main"

# Crear workspace
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo -e "${BLUE}[*] === WIREGUARD MASTER SETUP ===${NC}"
echo -e "${BLUE}[*] VPS: $VPS_IP | RPi: $RPI_IP${NC}"
echo

# ============================================================================
# PASO 1: Obtener wg0.conf desde VPS
# ============================================================================
echo -e "${YELLOW}[1/4] Descargando wg0.conf desde VPS...${NC}"

# Buscar directorio wireguard
VPS_DIR=$(sshpass -p "$VPS_PASS" ssh $SSH_OPTS "$VPS_USER@$VPS_IP" \
  'ls -td /tmp/wireguard-totem-* 2>/dev/null | head -1' 2>/dev/null || echo "")

if [ -z "$VPS_DIR" ]; then
  echo -e "${RED}[ERROR] No se encontró configuración en VPS${NC}"
  echo -e "  Ejecuta en VPS: curl -fL $REPO_URL/generate-wg-peer.sh | bash"
  exit 1
fi

echo "  [*] Directorio: $VPS_DIR"

# Descargar archivo
if ! sshpass -p "$VPS_PASS" scp $SSH_OPTS \
  "$VPS_USER@$VPS_IP:$VPS_DIR/wg0.conf" "$WORK_DIR/wg0.conf" 2>/dev/null; then
  echo -e "${RED}[ERROR] Fallo de descarga${NC}"
  exit 1
fi

echo -e "${GREEN}[✓] wg0.conf descargado${NC}"

# ============================================================================
# PASO 2: Transferir a RPi
# ============================================================================
echo -e "${YELLOW}[2/4] Transfiriendo a RPi ($RPI_IP)...${NC}"

if ! sshpass -p "$RPI_PASS" scp $SSH_OPTS \
  "$WORK_DIR/wg0.conf" "$RPI_USER@$RPI_IP:~/" 2>/dev/null; then
  echo -e "${RED}[ERROR] Transferencia falló${NC}"
  exit 1
fi

echo -e "${GREEN}[✓] Archivo en RPi${NC}"

# ============================================================================
# PASO 3: Descargar e instalar TOTEM-WG-SETUP.sh
# ============================================================================
echo -e "${YELLOW}[3/4] Preparando herramientas en RPi...${NC}"

WG_SETUP_SCRIPT=$(curl -fL "$REPO_URL/TOTEM-WG-SETUP.sh" 2>/dev/null)

if [ -z "$WG_SETUP_SCRIPT" ]; then
  echo -e "${RED}[ERROR] No se pudo descargar script de configuración${NC}"
  exit 1
fi

# Transferir script
sshpass -p "$RPI_PASS" scp $SSH_OPTS /dev/stdin "$RPI_USER@$RPI_IP:TOTEM-WG-SETUP.sh" \
  <<< "$WG_SETUP_SCRIPT" 2>/dev/null

echo -e "${GREEN}[✓] Script en RPi${NC}"

# ============================================================================
# PASO 4: Ejecutar configuración
# ============================================================================
echo -e "${YELLOW}[4/4] Aplicando WireGuard...${NC}"

# Ejecutar remoto
if sshpass -p "$RPI_PASS" ssh $SSH_OPTS "$RPI_USER@$RPI_IP" \
  'echo "$RPI_PASS" | sudo -S bash ~/TOTEM-WG-SETUP.sh' 2>&1 | grep -E "✓|ERROR"; then
  echo -e "${GREEN}[✓] Aplicación completada${NC}"
else
  echo -e "${YELLOW}[!] Verifícalo manualmente en RPi${NC}"
fi

# ============================================================================
# PASO 5: Verificación rápida
# ============================================================================
echo
echo -e "${BLUE}Verificando...${NC}"

if sshpass -p "$RPI_PASS" ssh $SSH_OPTS "$RPI_USER@$RPI_IP" \
  'ip addr show wg0 2>/dev/null | grep -q 10.0.0.2' 2>/dev/null; then
  echo -e "${GREEN}[✓] Interface wg0 activa${NC}"
  sshpass -p "$RPI_PASS" ssh $SSH_OPTS "$RPI_USER@$RPI_IP" \
    'ip addr show wg0 | grep inet' 2>/dev/null | sed 's/^/    /'
else
  echo -e "${YELLOW}[!] Verifica manualmente: ssh vidloop@$RPI_IP 'ip addr show wg0'${NC}"
fi

# ============================================================================
# LIMPIAR
# ============================================================================
sshpass -p "$VPS_PASS" ssh $SSH_OPTS "$VPS_USER@$VPS_IP" \
  "rm -rf $VPS_DIR" 2>/dev/null || true

rm -rf "$WORK_DIR"

echo
echo -e "${GREEN}[✓] === SETUP COMPLETADO ===${NC}"
echo
echo -e "${BLUE}Siguientes pasos:${NC}"
echo "  1. Dashboard ya debería estar accesible"
echo "  2. Intenta subir un video"
echo "  3. Si hay issues: ssh $RPI_USER@$RPI_IP 'sudo wg show wg0'"
echo

