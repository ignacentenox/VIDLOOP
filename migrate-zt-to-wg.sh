#!/usr/bin/env bash
set -euo pipefail

# ================================================================
#  MIGRATE ZeroTier → WireGuard
#  Migra una o varias RPis de la VPN ZeroTier al VPS WireGuard
#  Desarrollado por IGNACE — 44 Contenidos
# ================================================================
#
# DESCRIPCIÓN:
#   Este script se ejecuta desde la máquina de gestión (Mac/PC) o
#   desde el VPS. Para cada RPi listada en el CSV:
#     1. Conecta vía SSH usando la dirección ZeroTier actual
#     2. Genera el par de claves WG en el VPS y registra el peer
#     3. Despliega la config WG en la RPi
#     4. Activa wg-quick@wg0 y verifica conectividad
#     5. Desinstala zerotier-one (opcional, REMOVE_ZEROTIER=true)
#     6. Actualiza el registro en /opt/vidloop-dash/rpis.csv del VPS
#
# USO:
#   ./migrate-zt-to-wg.sh                    → usa rpis.csv en CWD
#   ./migrate-zt-to-wg.sh mis-rpis.csv
#   REMOVE_ZEROTIER=true ./migrate-zt-to-wg.sh
#   DRY_RUN=true ./migrate-zt-to-wg.sh
#
# FORMATO rpis.csv (igual que deploy-vidloop.sh):
#   nombre,host_zerotier,usuario,password[,puerto[,wg_ip]]
#
# VARIABLES DE ENTORNO:
#   VPS_IP          IP del servidor VPS WireGuard   (default: 82.25.77.55)
#   VPS_USER        Usuario SSH del VPS              (default: root)
#   VPS_PASS        Password SSH del VPS             (default: Vidloop@44tech)
#   VPS_WG_IF       Interfaz WireGuard del VPS       (default: wg0)
#   WG_BASE_IP      Prefijo red WireGuard            (default: 10.0.0)
#   WG_IP_START     Primer octeto libre              (default: 4)
#   REMOVE_ZEROTIER true = desinstala zerotier-one   (default: false)
#   DRY_RUN         true = solo simular              (default: false)
#   LOG_DIR         Directorio de logs               (default: ./migrate-logs/TIMESTAMP)
# ================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BOLD}${CYAN}══ $1 ══${NC}"; }

# ── CONFIGURACIÓN ─────────────────────────────────────────────────
VPS_IP="${VPS_IP:-82.25.77.55}"
VPS_USER="${VPS_USER:-root}"
VPS_PASS="${VPS_PASS:-Vidloop@44tech}"
VPS_WG_IF="${VPS_WG_IF:-wg0}"
WG_BASE_IP="${WG_BASE_IP:-10.0.0}"
WG_IP_START="${WG_IP_START:-4}"
REMOVE_ZEROTIER="${REMOVE_ZEROTIER:-false}"
DRY_RUN="${DRY_RUN:-false}"
VPS_RPIS_CSV="${VPS_RPIS_CSV:-/opt/vidloop-dash/rpis.csv}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/migrate-logs/$TIMESTAMP}"
CSV_FILE="${1:-$SCRIPT_DIR/rpis.csv}"

# ── SSH helpers ───────────────────────────────────────────────────
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=no"

_ssh_rpi() {
    local user="$1" host="$2" pass="$3" port="${4:-22}"
    shift 4
    sshpass -p "$pass" ssh $SSH_OPTS -p "$port" "$user@$host" "$@"
}

_vps() {
    sshpass -p "$VPS_PASS" ssh $SSH_OPTS "$VPS_USER@$VPS_IP" "$@"
}

# ── VALIDACIONES ──────────────────────────────────────────────────
validate_deps() {
    local missing=()
    command -v sshpass >/dev/null 2>&1 || missing+=("sshpass")
    command -v ssh     >/dev/null 2>&1 || missing+=("ssh")
    if [ "${#missing[@]}" -gt 0 ]; then
        log_error "Dependencias faltantes: ${missing[*]}"
        echo "  macOS: brew install hudochenkov/sshpass/sshpass"
        echo "  Linux: sudo apt-get install -y sshpass"
        exit 1
    fi
    if [ ! -f "$CSV_FILE" ]; then
        log_error "CSV no encontrado: $CSV_FILE"
        exit 1
    fi
}

# ── GENERAR CONFIG WG EN VPS (reutiliza lógica de deploy-vidloop) ─
generate_wg_for_rpi() {
    local name="$1" wg_ip="$2"

    _vps bash -s -- "$name" "$wg_ip" "$VPS_WG_IF" <<'VPS_EOF'
#!/usr/bin/env bash
set -euo pipefail
NAME="$1"; WG_IP="$2"; WG_IF="$3"
WG_CONF="/etc/wireguard/${WG_IF}.conf"

ip link show "$WG_IF" >/dev/null 2>&1 || { echo "ERROR: $WG_IF no activo" >&2; exit 1; }

VPS_PRIV=$(grep -m1 '^\s*PrivateKey' "$WG_CONF" | awk '{print $3}')
[ -z "$VPS_PRIV" ] && [ -f /etc/wireguard/server.key ] && VPS_PRIV=$(cat /etc/wireguard/server.key)
[ -z "$VPS_PRIV" ] && { echo "ERROR: Clave privada del servidor no encontrada" >&2; exit 1; }
VPS_PUB=$(echo "$VPS_PRIV" | wg pubkey)
WG_PORT=$(wg show "$WG_IF" listen-port 2>/dev/null || echo "51820")

VPS_PUBLIC_IP=""
[ -f /etc/wireguard/.vps_public_ip ] && VPS_PUBLIC_IP=$(cat /etc/wireguard/.vps_public_ip)
[ -z "$VPS_PUBLIC_IP" ] && VPS_PUBLIC_IP=$(curl -fs --max-time 4 ifconfig.me || echo "82.25.77.55")
echo "$VPS_PUBLIC_IP" > /etc/wireguard/.vps_public_ip

WG_SUBNET=$(ip addr show "$WG_IF" | grep 'inet ' | awk '{print $2}' | head -1 | sed 's|\.[0-9]*/.*|.0/24|')
[ -z "$WG_SUBNET" ] && WG_SUBNET="10.0.0.0/24"

WORK=$(mktemp -d); trap "rm -rf $WORK" EXIT
wg genkey | tee "$WORK/rpi.key" | wg pubkey > "$WORK/rpi.pub"
RPI_PRIV=$(cat "$WORK/rpi.key"); RPI_PUB=$(cat "$WORK/rpi.pub")

# Eliminar peer antiguo con esa IP si existe
OLD=$(wg show "$WG_IF" allowed-ips 2>/dev/null | grep "${WG_IP}/32" | awk '{print $1}' || true)
[ -n "$OLD" ] && [ "$OLD" != "$RPI_PUB" ] && wg set "$WG_IF" peer "$OLD" remove 2>/dev/null || true

wg set "$WG_IF" peer "$RPI_PUB" allowed-ips "${WG_IP}/32"

# Persistir en wg0.conf
if [ -f "$WG_CONF" ]; then
    TMP=$(mktemp)
    awk -v k="$RPI_PUB" '
        /^\[Peer\]/{in_p=1;buf="";skip=0}
        in_p{buf=buf $0 "\n"}
        in_p && $0~k{skip=1}
        in_p && /^$/{if(!skip)printf "%s\n",buf;in_p=0;buf="";skip=0;next}
        !in_p{print}
        END{if(in_p&&!skip)printf "%s",buf}
    ' "$WG_CONF" > "$TMP" && mv "$TMP" "$WG_CONF"
fi
printf '\n# Peer: %s (migrado desde ZeroTier) — %s\n[Peer]\nPublicKey = %s\nAllowedIPs = %s/32\n' \
    "$NAME" "$(date -Iseconds)" "$RPI_PUB" "$WG_IP" >> "$WG_CONF"

cat > "$WORK/rpi_wg0.conf" <<RPICONF
[Interface]
PrivateKey = ${RPI_PRIV}
Address = ${WG_IP}/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${VPS_PUB}
Endpoint = ${VPS_PUBLIC_IP}:${WG_PORT}
AllowedIPs = ${WG_SUBNET}
PersistentKeepalive = 25
RPICONF

echo "WG_CONFIG_B64=$(base64 -w0 "$WORK/rpi_wg0.conf" 2>/dev/null || base64 "$WORK/rpi_wg0.conf")"
VPS_EOF
}

# ── MIGRAR UNA RPi ────────────────────────────────────────────────
migrate_rpi() {
    local name="$1" host="$2" user="$3" pass="$4" port="$5" wg_ip="$6"
    local log_file="$LOG_DIR/${name}.log"

    {
        echo "════════════════════════════════════════"
        echo " MIGRAR: $name  ($host → WG:$wg_ip)"
        echo " Inicio: $(date)"
        echo "════════════════════════════════════════"

        # 1. Test SSH por ZeroTier
        echo "[1/6] Verificando SSH a $host..."
        _ssh_rpi "$user" "$host" "$pass" "$port" "echo OK" &>/dev/null || {
            echo "ERROR: Sin conexión SSH a $host:$port"
            return 1
        }
        echo "      → SSH OK (ZeroTier activo)"

        # 2. Verificar que ZeroTier está corriendo en la RPi
        echo "[2/6] Verificando ZeroTier en RPi..."
        ZT_STATUS=$(_ssh_rpi "$user" "$host" "$pass" "$port" \
            "systemctl is-active zerotier-one 2>/dev/null || echo inactive")
        echo "      → ZeroTier: $ZT_STATUS"
        if [ "$ZT_STATUS" = "inactive" ]; then
            echo "WARN: zerotier-one no activo en $host, continuando igual..."
        fi

        # 3. Generar config WG en VPS
        echo "[3/6] Generando config WireGuard en VPS para $name ($wg_ip)..."
        VPS_OUT=$(generate_wg_for_rpi "$name" "$wg_ip" 2>&1) || {
            echo "ERROR: Fallo generación WG en VPS: $VPS_OUT"
            return 1
        }
        WG_B64=$(echo "$VPS_OUT" | grep "^WG_CONFIG_B64=" | cut -d= -f2- | tr -d '\n' || true)
        if [ -z "$WG_B64" ]; then
            echo "ERROR: No se obtuvo config WG del VPS"
            echo "       Output: $VPS_OUT"
            return 1
        fi
        echo "      → WG config generado OK"

        # 4. Aplicar WireGuard en la RPi
        echo "[4/6] Aplicando WireGuard en RPi $host..."
        _ssh_rpi "$user" "$host" "$pass" "$port" bash -s -- "$WG_B64" <<'RPI_WG'
#!/usr/bin/env bash
set -euo pipefail
WG_B64="$1"
WG_IF="wg0"
WG_PATH="/etc/wireguard/${WG_IF}.conf"

# Instalar WireGuard si falta
if ! command -v wg >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y wireguard wireguard-tools 2>/dev/null || {
        echo "ERROR: No se pudo instalar wireguard"
        exit 1
    }
fi

# Aplicar config
mkdir -p /etc/wireguard
echo "$WG_B64" | base64 -d > "$WG_PATH"
chmod 600 "$WG_PATH"

# Detener interfaz si ya estaba levantada (evita conflicto)
systemctl stop "wg-quick@${WG_IF}" 2>/dev/null || true

# Activar
systemctl enable --now "wg-quick@${WG_IF}" || {
    echo "ERROR: wg-quick@${WG_IF} falló al iniciar"
    exit 1
}
echo "WG_UP=ok"
RPI_WG
        echo "      → WireGuard aplicado en RPi"

        # 5. Verificar conectividad WG (RPi→VPS ping)
        echo "[5/6] Verificando conectividad WireGuard..."
        sleep 4
        VPS_WG_IP=$(echo "$WG_BASE_IP" | sed 's/\.[0-9]*$//').1
        PING_OK=$(_ssh_rpi "$user" "$host" "$pass" "$port" \
            "ping -c 2 -W 3 $VPS_WG_IP 2>/dev/null | grep -c '0% packet loss'" || echo "0")
        if [ "$PING_OK" != "0" ]; then
            echo "      → Ping al VPS ($VPS_WG_IP) OK"
        else
            echo "WARN: Ping al VPS no respondió (puede ser firewall, WG igual puede funcionar)"
        fi

        # 6. Desinstalar ZeroTier (opcional)
        if [[ "$REMOVE_ZEROTIER" == "true" ]]; then
            echo "[6/6] Desinstalando zerotier-one..."
            _ssh_rpi "$user" "$host" "$pass" "$port" \
                "sudo systemctl stop zerotier-one 2>/dev/null; sudo apt-get remove -y zerotier-one 2>/dev/null; sudo rm -rf /var/lib/zerotier-one" \
                && echo "      → ZeroTier eliminado" \
                || echo "WARN: No se pudo desinstalar ZeroTier completamente"
        else
            echo "[6/6] ZeroTier conservado (REMOVE_ZEROTIER=false)"
        fi

        # Actualizar registro en VPS
        sshpass -p "$VPS_PASS" ssh $SSH_OPTS "$VPS_USER@$VPS_IP" bash -s -- \
            "$name" "$host" "$user" "$pass" "$port" "$wg_ip" "$VPS_RPIS_CSV" <<'VPS_REG'
NAME="$1";HOST="$2";U="$3";P="$4";PORT="$5";WG="$6";CSV="$7"
mkdir -p "$(dirname "$CSV")"; touch "$CSV"
TMP=$(mktemp)
grep -v "^${NAME}," "$CSV" | grep -v ",${HOST}," > "$TMP" 2>/dev/null || true
echo "${NAME},${HOST},${U},${P},${PORT},${WG}" >> "$TMP"
mv "$TMP" "$CSV"; chmod 600 "$CSV"
VPS_REG

        echo
        echo "RESULTADO: ÉXITO — $name migrado a WireGuard $wg_ip"
        echo "Fin: $(date)"
    } >> "$log_file" 2>&1
}

# ── LEER CSV ──────────────────────────────────────────────────────
_CSV_ENTRIES_FILE=""
read_csv() {
    local csv="$1"
    local wg_counter="$WG_IP_START"
    _CSV_ENTRIES_FILE=$(mktemp)
    local line_num=0

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line//[[:space:]]/}" ]] && continue

        IFS=',' read -r name host user pass port wg_ip <<< "$line"
        name="${name// /}"; host="${host// /}"; user="${user// /}"
        pass="${pass// /}"; port="${port:-22}"; port="${port// /}"
        wg_ip="${wg_ip// /}"

        [ -z "$name" ] || [ -z "$host" ] || [ -z "$user" ] || [ -z "$pass" ] && {
            log_warn "CSV línea $line_num ignorada: $line"; continue
        }

        [ -z "$wg_ip" ] && { wg_ip="${WG_BASE_IP}.${wg_counter}"; wg_counter=$((wg_counter+1)); }
        echo "$name|$host|$user|$pass|$port|$wg_ip" >> "$_CSV_ENTRIES_FILE"
    done < "$csv"
}

# ── MAIN ──────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}${BLUE}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║  MIGRATE ZeroTier → WireGuard                ║"
    echo "  ║  Powered by 44 Contenidos — IGNACE           ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${NC}"

    log_section "Validando dependencias"
    validate_deps
    log_ok "Deps OK | CSV: $CSV_FILE"

    mkdir -p "$LOG_DIR"
    log_ok "Logs en: $LOG_DIR"

    log_section "Leyendo RPis"
    read_csv "$CSV_FILE"
    local total; total=$(wc -l < "$_CSV_ENTRIES_FILE" | tr -d ' ')
    [ "$total" -eq 0 ] && { log_error "No se encontraron RPis en $CSV_FILE"; exit 1; }
    log_ok "$total RPis a migrar"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_section "DRY RUN — sin cambios"
        printf "%-20s %-20s %-6s %-15s\n" "NOMBRE" "HOST ZT" "PUERTO" "WG_IP"
        printf '%.0s─' {1..65}; echo
        while IFS='|' read -r name host user pass port wg_ip; do
            printf "%-20s %-20s %-6s %-15s\n" "$name" "$host" "$port" "$wg_ip"
        done < "$_CSV_ENTRIES_FILE"
        rm -f "$_CSV_ENTRIES_FILE"
        log_ok "DRY_RUN=true — nada ejecutado"
        exit 0
    fi

    log_section "Verificando VPS"
    if _vps "ip link show $VPS_WG_IF" &>/dev/null; then
        log_ok "VPS $VPS_IP → interfaz $VPS_WG_IF activa"
    else
        log_error "VPS $VPS_IP — interfaz $VPS_WG_IF NO activa"
        log_error "Activar en VPS: wg-quick up $VPS_WG_IF"
        exit 1
    fi

    log_section "Iniciando migración"
    local ok=0 fail=0

    while IFS='|' read -r name host user pass port wg_ip; do
        echo
        log_info "Migrando $name ($host) → WG:$wg_ip ..."
        if migrate_rpi "$name" "$host" "$user" "$pass" "$port" "$wg_ip"; then
            log_ok "$name → WG:$wg_ip [OK]"
            ok=$((ok+1))
        else
            log_warn "$name → FALLÓ — ver: $LOG_DIR/${name}.log"
            fail=$((fail+1))
        fi
    done < "$_CSV_ENTRIES_FILE"

    rm -f "$_CSV_ENTRIES_FILE"

    log_section "RESUMEN"
    echo "  Total:  $((ok+fail))"
    echo -e "  ${GREEN}Éxito:  $ok${NC}"
    echo -e "  ${RED}Fallo:  $fail${NC}"
    echo "  Logs:   $LOG_DIR"
    echo
    [ "$fail" -eq 0 ] && log_ok "Migración completada sin errores." || log_warn "$fail RPis fallaron."

    if [[ "$REMOVE_ZEROTIER" != "true" ]]; then
        echo
        log_warn "ZeroTier NO fue desinstalado (REMOVE_ZEROTIER=false)."
        log_warn "Cuando confirmes que WireGuard funciona, ejecutar:"
        log_warn "  REMOVE_ZEROTIER=true ./migrate-zt-to-wg.sh"
    fi

    return "$fail"
}

main "$@"
