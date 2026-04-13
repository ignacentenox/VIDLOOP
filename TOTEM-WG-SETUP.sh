#!/bin/bash

################################################################################
# TOTEM-WG-SETUP.sh
# Script rápido para aplicar WireGuard en TOTEM LANSER 2
# Uso: bash <(curl -fL https://raw.github...TOTEM-WG-SETUP.sh)
# O: chmod +x TOTEM-WG-SETUP.sh && sudo ./TOTEM-WG-SETUP.sh
################################################################################

set -e

echo "[*] Configurando WireGuard en TOTEM..."

# Variables
WG_FILE="${1:~/wg0.conf}"
WG_CONF="/etc/wireguard/wg0.conf"

# Validar
if [ ! -f "$WG_FILE" ]; then
  echo "[ERROR] No se encontró $WG_FILE"
  echo "La configuración debe estar en ~/.wg0.conf o especificar ruta"
  exit 1
fi

# Preparar
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

# Backup
[ -f "$WG_CONF" ] && cp "$WG_CONF" "$WG_CONF.bak.$(date +%s.%N)"

# Copiar config
cp "$WG_FILE" "$WG_CONF"
chmod 600 "$WG_CONF"

# Instalar si falta
if ! command -v wg >/dev/null 2>&1; then
  echo "[*] Instalando WireGuard..."
  apt-get update -qq 2>/dev/null || true
  apt-get install -y wireguard wireguard-tools openresolv 2>&1 | grep -v "^Reading\|^Unpacking\|^Setting" || true
fi

# Bajar interfaz anterior si existe
if ip link show wg0 >/dev/null 2>&1; then
  echo "[*] Bajando interfaz anterior..."
  ip link del wg0 2>/dev/null || true
fi

# Crear interfaz
echo "[*] Creando interfaz wg0..."
ip link add dev wg0 type wireguard
ip addr add 10.0.0.2/24 dev wg0

# Extraer claves
PRIV_KEY=$(grep '^PrivateKey' "$WG_CONF" | awk '{print $3}')
PUB_KEY=$(grep '^PublicKey' "$WG_CONF" | awk '{print $3}')
ENDPOINT=$(grep '^Endpoint' "$WG_CONF" | awk '{print $3}')

# Aplicar
echo "[*] Aplicando llaves..."
wg set wg0 private-key <(echo "$PRIV_KEY")
wg set wg0 peer "$PUB_KEY" endpoint "$ENDPOINT" allowed-ips 10.0.0.1/24 persistent-keepalive 25

# Activar
echo "[*] Activando interfaz..."
ip link set up dev wg0

# Verificar
sleep 1
if ip link show wg0 >/dev/null 2>&1; then
  echo ""
  echo "[✓] WireGuard configurado exitosamente"
  echo ""
  echo "Estado:"
  ip addr show wg0 | grep "inet " | awk '{print "  IP: " $2}'
  echo "  Peer: $(wg show wg0 |head -1 | awk '{print "connected" }')"
  wg show wg0 | head -4 | tail -3 | sed 's/^/  /'
  echo ""
  echo "[✓] ¡Listo! Acceso VPN disponible"
else
  echo "[ERROR] Interfaz wg0 no se activó"
  exit 1
fi

