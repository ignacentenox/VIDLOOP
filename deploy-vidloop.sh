#!/usr/bin/env bash
set -euo pipefail

# ================================================================
#  VIDLOOP MASS DEPLOY v2.0
#  Despliegue masivo a 100+ RPis con WireGuard totalmente automático
#  Desarrollado por IGNACE — Powered by 44 Contenidos
# ================================================================
#
# USO BÁSICO:
#   ./deploy-vidloop.sh                   → usa rpis.csv en CWD
#   ./deploy-vidloop.sh mis-rpis.csv
#   MAX_PARALLEL=20 ./deploy-vidloop.sh
#   DRY_RUN=true ./deploy-vidloop.sh      → simula sin ejecutar
#
# FORMATO rpis.csv (# ignora líneas, sin header):
#   nombre,host,usuario,password[,wg_ip]
#   rpi-01,192.168.1.10,vidloop,4455,10.0.0.10
#   rpi-02,10.8.0.11,vidloop,4455          ← WG_IP se auto-asigna
#
# VARIABLES DE ENTORNO:
#   VPS_IP        IP del servidor VPS con WireGuard    (default: 82.25.77.55)
#   VPS_USER      Usuario SSH del VPS                   (default: root)
#   VPS_PASS      Password SSH del VPS                  (default: Vidloop@44tech)
#   VPS_WG_IF     Interfaz WireGuard en VPS             (default: wg0)
#   WG_BASE_IP    Prefijo red WireGuard privada          (default: 10.0.0)
#   WG_IP_START   Primer octeto disponible para RPis    (default: 10)
#   MAX_PARALLEL  Concurrencia máxima de deploys        (default: 8)
#   RETRY_COUNT   Reintentos por falla de RPi           (default: 2)
#   SKIP_WG       true = omitir configuración WireGuard (default: false)
#   DRY_RUN       true = solo simular, no ejecutar nada (default: false)
#   VIDLOOP_SCRIPT  Ruta al VIDLOOP-V3.0.sh              (default: auto)
#   LOG_DIR       Directorio de logs                    (default: ./deploy-logs/TIMESTAMP)
# ================================================================

# ── COLORES ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BOLD}${CYAN}══ $1 ══${NC}"; }

# ── CONFIGURACIÓN CON DEFAULTS ───────────────────────────────────
VPS_IP="${VPS_IP:-82.25.77.55}"
VPS_USER="${VPS_USER:-root}"
VPS_PASS="${VPS_PASS:-Vidloop@44tech}"
VPS_WG_IF="${VPS_WG_IF:-wg0}"
WG_BASE_IP="${WG_BASE_IP:-10.0.0}"
# Asignación automática empieza en .4:
#   10.0.0.2 → TOTEM LANSER 1 (fijo, 10.8.0.2 en su subred)
#   10.0.0.3 → TOTEM LANSER 2 (fijo)
#   10.0.0.4+ → nuevas RPis asignadas automáticamente
WG_IP_START="${WG_IP_START:-4}"
# Ruta en el VPS donde se mantiene el registro maestro de RPis
VPS_RPIS_CSV="${VPS_RPIS_CSV:-/opt/vidloop-dash/rpis.csv}"
MAX_PARALLEL="${MAX_PARALLEL:-8}"
RETRY_COUNT="${RETRY_COUNT:-2}"
SKIP_WG="${SKIP_WG:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Hallar VIDLOOP-V3.0.sh automáticamente
SCRIPT_DIR_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIDLOOP_SCRIPT="${VIDLOOP_SCRIPT:-$SCRIPT_DIR_SELF/VIDLOOP-V3.0.sh}"
VIDLOOP_INI="${VIDLOOP_SCRIPT%/*}/video_looper.ini"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR_SELF/deploy-logs/$TIMESTAMP}"

# Archivo CSV de entrada
CSV_FILE="${1:-$SCRIPT_DIR_SELF/rpis.csv}"

# ── CONTADORES GLOBALES (archivos en /tmp para compatibilidad con subshells) ──
_COUNTER_DIR="$(mktemp -d)"
echo 0 > "$_COUNTER_DIR/ok"
echo 0 > "$_COUNTER_DIR/fail"
echo 0 > "$_COUNTER_DIR/total"
_RESULTS_FILE="$_COUNTER_DIR/results.tsv"
touch "$_RESULTS_FILE"

# ── LIMPIEZA AL SALIR ─────────────────────────────────────────────
cleanup() {
    rm -rf "$_COUNTER_DIR"
}
trap cleanup EXIT

# ── VALIDACIONES INICIALES ────────────────────────────────────────
validate_dependencies() {
    local missing=()
    command -v sshpass >/dev/null 2>&1 || missing+=("sshpass")
    command -v ssh     >/dev/null 2>&1 || missing+=("ssh")
    command -v scp     >/dev/null 2>&1 || missing+=("scp")
    command -v awk     >/dev/null 2>&1 || missing+=("awk")
    command -v base64  >/dev/null 2>&1 || missing+=("base64")

    if [ "${#missing[@]}" -gt 0 ]; then
        log_error "Dependencias faltantes: ${missing[*]}"
        echo
        echo "  macOS:  brew install hudochenkov/sshpass/sshpass"
        echo "  Linux:  sudo apt-get install -y sshpass"
        exit 1
    fi
}

validate_files() {
    if [ ! -f "$VIDLOOP_SCRIPT" ]; then
        log_error "VIDLOOP-V3.0.sh no encontrado en: $VIDLOOP_SCRIPT"
        log_info  "Especificalo con: VIDLOOP_SCRIPT=/ruta/VIDLOOP-V3.0.sh ./deploy-vidloop.sh"
        exit 1
    fi
    if [ ! -f "$CSV_FILE" ]; then
        log_error "Archivo CSV no encontrado: $CSV_FILE"
        log_info  "Crealo copiando: cp rpis.example.csv rpis.csv"
        exit 1
    fi
}

# ── SSH HELPERS CON SSHPASS ───────────────────────────────────────

# Opciones SSH comunes (sin verificación de host para despliegue masivo)
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=8 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o BatchMode=no"

# Wrapper: ssh con password  
_ssh() {
    local user="$1" host="$2" pass="$3" port="${4:-22}"
    shift 4
    sshpass -p "$pass" ssh $SSH_OPTS -p "$port" "$user@$host" "$@"
}

# Wrapper: scp con password (local → remoto)
_scp_to() {
    local pass="$1" src="$2" user="$3" host="$4" dst="$5" port="${6:-22}"
    sshpass -p "$pass" scp -q $SSH_OPTS -P "$port" "$src" "$user@$host:$dst"
}

# Wrapper: ssh al VPS
_vps() {
    sshpass -p "$VPS_PASS" ssh $SSH_OPTS "$VPS_USER@$VPS_IP" "$@"
}

# ── WIREGUARD: GENERAR CONFIG EN VPS ─────────────────────────────
#
# Genera en el VPS:
#   1. Keypair para la RPi
#   2. Registra el peer en wg0 (hot-reload sin reiniciar)
#   3. Persiste en wg0.conf
#   4. Devuelve el config completo de la RPi como base64
#
# Args: $1 = nombre RPi, $2 = IP WireGuard para la RPi (ej: 10.0.0.15)
generate_wg_config_on_vps() {
    local rpi_name="$1"
    local rpi_wg_ip="$2"
    local wg_if="$VPS_WG_IF"

    # Script inline que se ejecuta en el VPS sobre SSH
    # Retorna SOLO la línea: WG_CONFIG_B64=<base64>
    _vps bash -s -- "$rpi_name" "$rpi_wg_ip" "$wg_if" <<'VPS_EOF'
#!/usr/bin/env bash
set -euo pipefail

RPI_NAME="$1"
RPI_WG_IP="$2"
WG_IF="$3"
WG_CONF="/etc/wireguard/${WG_IF}.conf"

# ── Verificar que WireGuard está activo ──────────────────────────
if ! command -v wg >/dev/null 2>&1; then
    echo "ERROR: wireguard-tools no instalado en VPS" >&2
    exit 1
fi

if ! ip link show "$WG_IF" >/dev/null 2>&1; then
    echo "ERROR: Interfaz $WG_IF no activa en VPS. Pon en marcha wg-quick@${WG_IF}" >&2
    exit 1
fi

# ── Extraer datos del servidor ───────────────────────────────────
VPS_PRIVATE_KEY=""
if [ -f "$WG_CONF" ]; then
    VPS_PRIVATE_KEY=$(grep -m1 '^\s*PrivateKey' "$WG_CONF" | awk '{print $3}' || true)
fi

# Fallback: buscar llave privada en archivo separado
if [ -z "$VPS_PRIVATE_KEY" ] && [ -f "/etc/wireguard/server-private.key" ]; then
    VPS_PRIVATE_KEY=$(cat /etc/wireguard/server-private.key)
fi

if [ -z "$VPS_PRIVATE_KEY" ]; then
    echo "ERROR: No se encontró clave privada del servidor VPS en $WG_CONF" >&2
    exit 1
fi

VPS_PUBLIC_KEY=$(echo "$VPS_PRIVATE_KEY" | wg pubkey)
WG_PORT=$(wg show "$WG_IF" listen-port 2>/dev/null || echo "51820")
VPS_ENDPOINT_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "82.25.77.55")

# Usar IP pública real si está configurada
if grep -q "^# VPS_PUBLIC_IP=" "$WG_CONF" 2>/dev/null; then
    VPS_ENDPOINT_IP=$(grep "^# VPS_PUBLIC_IP=" "$WG_CONF" | cut -d= -f2)
elif [ -f /etc/wireguard/.vps_public_ip ]; then
    VPS_ENDPOINT_IP=$(cat /etc/wireguard/.vps_public_ip)
else
    # Intentar detectar IP pública real
    DETECTED_IP=$(curl -fs --max-time 3 ifconfig.me || curl -fs --max-time 3 api.ipify.org || echo "")
    if [ -n "$DETECTED_IP" ]; then
        VPS_ENDPOINT_IP="$DETECTED_IP"
        echo "$DETECTED_IP" > /etc/wireguard/.vps_public_ip
    fi
fi

# ── Detectar subred configurada en VPS ──────────────────────────
VPS_WG_NETWORK=$(ip addr show "$WG_IF" | grep 'inet ' | awk '{print $2}' | head -1)
if [ -z "$VPS_WG_NETWORK" ]; then
    VPS_WG_NETWORK="10.0.0.1/24"
fi
WG_NETWORK_PREFIX=$(echo "$VPS_WG_NETWORK" | sed 's|\.[0-9]*/.*||')

# ── Generar keypair para esta RPi ────────────────────────────────
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

wg genkey | tee "$WORK_DIR/rpi.key" | wg pubkey > "$WORK_DIR/rpi.pub"
RPI_PRIVATE_KEY=$(cat "$WORK_DIR/rpi.key")
RPI_PUBLIC_KEY=$(cat "$WORK_DIR/rpi.pub")

# ── Verificar si el peer ya existe (idempotente) ─────────────────
if wg show "$WG_IF" peers 2>/dev/null | grep -qF "$RPI_PUBLIC_KEY"; then
    : # peer ya registrado, actualizamos allowed-ips
fi

# Verificar que la IP no está ya en uso por OTRO peer
EXISTING_PEER_WITH_IP=$(wg show "$WG_IF" allowed-ips 2>/dev/null | grep "${RPI_WG_IP}/32" | awk '{print $1}' || true)
if [ -n "$EXISTING_PEER_WITH_IP" ] && [ "$EXISTING_PEER_WITH_IP" != "$RPI_PUBLIC_KEY" ]; then
    # Eliminar peer antiguo con esa IP (fue reemplazo)
    wg set "$WG_IF" peer "$EXISTING_PEER_WITH_IP" remove 2>/dev/null || true
    # Limpiar de config persistente
    WG_TEMP=$(mktemp)
    awk "
        /^\[Peer\]/ { peer=1; block=\"\"; }
        peer { block = block \$0 \"\n\"; }
        peer && /AllowedIPs.*${RPI_WG_IP}\/32/ { skip=1; }
        peer && /^\[/ && !/^\[Peer\]/ { if(!skip) printf \"%s\", block; peer=0; skip=0; block=\"\"; }
        !peer { print; }
        END { if(peer && !skip) printf \"%s\", block; }
    " "$WG_CONF" > "$WG_TEMP" 2>/dev/null && mv "$WG_TEMP" "$WG_CONF" || true
fi

# ── Agregar/actualizar peer en VPS (hot, sin reiniciar WG) ──────
wg set "$WG_IF" \
    peer "$RPI_PUBLIC_KEY" \
    allowed-ips "${RPI_WG_IP}/32" \
    2>/dev/null

# ── Persistir peer en wg0.conf ──────────────────────────────────
# Eliminar entrada previa con esta clave pública (si existe)
if [ -f "$WG_CONF" ]; then
    WG_TEMP=$(mktemp)
    awk -v pubkey="$RPI_PUBLIC_KEY" '
        /^\[Peer\]/ { in_peer=1; block=""; }
        in_peer { block = block $0 "\n"; }
        in_peer && $0 ~ pubkey { skip_peer=1; }
        in_peer && /^$/ && in_peer {
            if (!skip_peer) printf "%s\n", block;
            in_peer=0; skip_peer=0; block="";
            next;
        }
        !in_peer { print; }
        END { if(in_peer && !skip_peer) printf "%s", block; }
    ' "$WG_CONF" > "$WG_TEMP" 2>/dev/null && mv "$WG_TEMP" "$WG_CONF" || true
fi

# Agregar nuevo bloque peer
cat >> "$WG_CONF" <<PEER_BLOCK

# Peer: ${RPI_NAME}  — generado: $(date -Iseconds)
[Peer]
PublicKey = ${RPI_PUBLIC_KEY}
AllowedIPs = ${RPI_WG_IP}/32
PEER_BLOCK

# ── Crear wg0.conf para la RPi ───────────────────────────────────
cat > "$WORK_DIR/rpi_wg0.conf" <<RPI_WG
[Interface]
PrivateKey = ${RPI_PRIVATE_KEY}
Address = ${RPI_WG_IP}/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${VPS_PUBLIC_KEY}
Endpoint = ${VPS_ENDPOINT_IP}:${WG_PORT}
AllowedIPs = ${WG_NETWORK_PREFIX}.0/24
PersistentKeepalive = 25
RPI_WG

# ── Devolver config como base64 (una sola línea) ─────────────────
echo "WG_CONFIG_B64=$(base64 -w0 "$WORK_DIR/rpi_wg0.conf" 2>/dev/null || base64 "$WORK_DIR/rpi_wg0.conf")"

VPS_EOF
}

# ── DESPLEGAR UNA RPi ─────────────────────────────────────────────
#
# Args: $1=nombre $2=host $3=usuario $4=password $5=puerto $6=wg_ip
# Escribe resultado en LOG_DIR/<nombre>.log
# Sale con 0=éxito, 1=fallo
deploy_rpi() {
    local name="$1"
    local host="$2"
    local user="$3"
    local pass="$4"
    local port="${5:-22}"
    local wg_ip="$6"
    local log_file="$LOG_DIR/${name}.log"

    {
        echo "════════════════════════════════════════"
        echo " DEPLOY: $name  ($host)"
        echo " Inicio: $(date)"
        echo "════════════════════════════════════════"

        # ── 1. Test de conectividad SSH ─────────────────────────
        echo "[1/5] Verificando conexión SSH a $host..."
        if ! _ssh "$user" "$host" "$pass" "$port" "echo OK" &>/dev/null; then
            echo "ERROR: No se puede conectar a $host:$port (user=$user)"
            return 1
        fi
        echo "      → SSH OK"

        # ── 2. Generar config WireGuard en VPS ─────────────────
        local wg_config_b64=""
        if [[ "$SKIP_WG" != "true" ]] && [[ -n "$wg_ip" ]]; then
            echo "[2/5] Generando config WireGuard en VPS para $name ($wg_ip)..."
            local vps_output
            vps_output=$(generate_wg_config_on_vps "$name" "$wg_ip" 2>&1) || {
                echo "WARN: Fallo de generación WireGuard en VPS: $vps_output"
                echo "      → Se desplegará SIN WireGuard"
            }
            wg_config_b64=$(echo "$vps_output" | grep "^WG_CONFIG_B64=" | cut -d= -f2- | tr -d '\n' || true)
            if [ -n "$wg_config_b64" ]; then
                echo "      → WG config generado OK"
            else
                echo "WARN: No se obtuvo config WireGuard del VPS"
            fi
        else
            echo "[2/5] WireGuard omitido (SKIP_WG=true o sin WG_IP asignada)"
        fi

        # ── 3. Subir archivos a la RPi ──────────────────────────
        echo "[3/5] Subiendo VIDLOOP-V3.0.sh a $host..."
        local remote_dir="/tmp/vidloop_deploy_$$"
        _ssh "$user" "$host" "$pass" "$port" "mkdir -p $remote_dir" || {
            echo "ERROR: No se pudo crear directorio remoto"
            return 1
        }
        _scp_to "$pass" "$VIDLOOP_SCRIPT" "$user" "$host" "$remote_dir/VIDLOOP-V3.0.sh" "$port" || {
            echo "ERROR: SCP de VIDLOOP-V3.0.sh falló"
            return 1
        }
        if [ -f "$VIDLOOP_INI" ]; then
            _scp_to "$pass" "$VIDLOOP_INI" "$user" "$host" "$remote_dir/video_looper.ini" "$port" || true
        fi
        echo "      → Archivos subidos OK"

        # ── 4. Ejecutar instalador en RPi ───────────────────────
        echo "[4/5] Ejecutando instalador en $host..."
        local env_vars="VIDLOOP_NONINTERACTIVE=true VIDLOOP_AUTO_REBOOT=false"
        if [ -n "$wg_config_b64" ]; then
            env_vars="$env_vars VIDLOOP_WG_CONFIG_B64=$wg_config_b64 ENABLE_WIREGUARD=true"
        else
            env_vars="$env_vars ENABLE_WIREGUARD=false"
        fi

        # Ejecutar con sudo, capturar salida completa
        local install_ok=false
        _ssh "$user" "$host" "$pass" "$port" \
            "cd $remote_dir && chmod +x VIDLOOP-V3.0.sh && sudo env $env_vars bash VIDLOOP-V3.0.sh" && install_ok=true

        if [ "$install_ok" != "true" ]; then
            echo "ERROR: Instalación falló en $host"
            _ssh "$user" "$host" "$pass" "$port" "rm -rf $remote_dir" 2>/dev/null || true
            return 1
        fi
        echo "      → Instalación completada"

        # ── 5. Limpieza y validación post-deploy ────────────────
        echo "[5/5] Limpieza y validación en $host..."
        _ssh "$user" "$host" "$pass" "$port" "rm -rf $remote_dir" 2>/dev/null || true

        # Validación rápida: verificar que SSH sigue activo (RPi no reinició aún)
        if _ssh "$user" "$host" "$pass" "$port" "id" &>/dev/null; then
            echo "      → RPi responde post-instalación OK"
        else
            echo "      → RPi no responde (puede estar reiniciando — normal)"
        fi

        echo
        echo "RESULTADO: ÉXITO — $name ($host)"
        echo "Fin: $(date)"
    } >> "$log_file" 2>&1

    return 0
}

# ── LEER CSV Y ESCRIBIR ENTRIES A ARCHIVO TEMPORAL ───────────────
# Escribe cada entry en $_CSV_ENTRIES_FILE (una por línea), compatible bash 3.2+
_CSV_ENTRIES_FILE=""

read_csv() {
    local csv="$1"
    local wg_counter="$WG_IP_START"
    local line_num=0
    _CSV_ENTRIES_FILE=$(mktemp)

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        # Ignorar comentarios y líneas vacías
        case "$line" in \#*|''|*\ *\ ) continue ;; esac
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line//[[:space:]]/}" ]] && continue

        # Parsear campos: nombre,host,usuario,password[,puerto[,wg_ip]]
        IFS=',' read -r name host user pass port wg_ip <<< "$line"
        name="${name// /}"
        host="${host// /}"
        user="${user// /}"
        pass="${pass// /}"
        port="${port// /}"
        port="${port:-22}"
        wg_ip="${wg_ip// /}"

        if [ -z "$name" ] || [ -z "$host" ] || [ -z "$user" ] || [ -z "$pass" ]; then
            log_warn "CSV línea $line_num ignorada (formato inválido): $line"
            continue
        fi

        # Auto-asignar WG IP si no se especificó
        if [ -z "$wg_ip" ]; then
            wg_ip="${WG_BASE_IP}.${wg_counter}"
            wg_counter=$((wg_counter + 1))
        fi

        echo "$name|$host|$user|$pass|$port|$wg_ip" >> "$_CSV_ENTRIES_FILE"
    done < "$csv"
}

# ── SEMÁFORO PARA CONTROL DE PARALELISMO ─────────────────────────
#
# Implementación simple con un directorio en /tmp como semáforo
_SEM_DIR=$(mktemp -d)
_sem_acquire() {
    # Espera hasta que haya un slot disponible (archivos en _SEM_DIR)
    local slots="$MAX_PARALLEL"
    while true; do
        local active
        active=$(ls "$_SEM_DIR" 2>/dev/null | wc -l)
        if [ "$active" -lt "$slots" ]; then
            touch "$_SEM_DIR/$$"
            return 0
        fi
        sleep 0.5
    done
}
_sem_release() {
    rm -f "$_SEM_DIR/$$" 2>/dev/null || true
}

# ── REGISTRAR RPi EN CSV MAESTRO DEL VPS ─────────────────────────
# Después de cada deploy exitoso, agrega/actualiza la línea en VPS_RPIS_CSV
# Formato: nombre,host,usuario,password,puerto,wg_ip
_register_rpi_in_vps() {
    local name="$1" host="$2" pass="$3" port="$4" wg_ip="$5"
    local user_rpi="vidloop"  # usuario SSH de la RPi (ya instalado)

    _vps bash -s -- "$name" "$host" "$user_rpi" "$pass" "$port" "$wg_ip" "$VPS_RPIS_CSV" <<'VPS_REG'
#!/usr/bin/env bash
NAME="$1"; HOST="$2"; USER="$3"; PASS="$4"; PORT="$5"; WG_IP="$6"; CSV="$7"
mkdir -p "$(dirname "$CSV")"
touch "$CSV"
# Eliminar entrada previa con este nombre o IP
TMP=$(mktemp)
grep -v "^${NAME}," "$CSV" | grep -v ",${HOST}," > "$TMP" 2>/dev/null || true
echo "${NAME},${HOST},${USER},${PASS},${PORT},${WG_IP}" >> "$TMP"
mv "$TMP" "$CSV"
chmod 600 "$CSV"   # proteger passwords
VPS_REG
}

# ── WORKER: deploy con retry ──────────────────────────────────────
deploy_with_retry() {
    local name="$1" host="$2" user="$3" pass="$4" port="$5" wg_ip="$6"
    local attempts=0
    local success=false

    while [ "$attempts" -le "$RETRY_COUNT" ]; do
        if deploy_rpi "$name" "$host" "$user" "$pass" "$port" "$wg_ip"; then
            success=true
            break
        fi
        attempts=$((attempts + 1))
        if [ "$attempts" -le "$RETRY_COUNT" ]; then
            echo "[RETRY] $name — intento $attempts/$RETRY_COUNT en 5s..." >> "$LOG_DIR/${name}.log"
            sleep 5
        fi
    done

    if [ "$success" = "true" ]; then
        # Thread-safe counter increment
        (
            flock 200
            local n; n=$(cat "$_COUNTER_DIR/ok"); echo $((n+1)) > "$_COUNTER_DIR/ok"
            echo -e "OK\t$name\t$host\t$wg_ip" >> "$_RESULTS_FILE"
        ) 200>"$_COUNTER_DIR/.lock"
        # Registrar en rpis.csv del VPS (idempotente)
        _register_rpi_in_vps "$name" "$host" "$pass" "22" "$wg_ip" 2>/dev/null || true
        echo -e "${GREEN}[OK]${NC} $name ($host) — ${wg_ip}"
    else
        (
            flock 200
            local n; n=$(cat "$_COUNTER_DIR/fail"); echo $((n+1)) > "$_COUNTER_DIR/fail"
            echo -e "FAIL\t$name\t$host\t$wg_ip" >> "$_RESULTS_FILE"
        ) 200>"$_COUNTER_DIR/.lock"
        echo -e "${RED}[FAIL]${NC} $name ($host) — ver: $LOG_DIR/${name}.log"
    fi

    _sem_release
}

# ── MAIN ──────────────────────────────────────────────────────────
main() {

    echo -e "${BOLD}${BLUE}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║     VIDLOOP MASS DEPLOY v2.0                 ║"
    echo "  ║     Powered by 44 Contenidos — IGNACE        ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${NC}"

    log_section "Validando dependencias"
    validate_dependencies
    validate_files
    log_ok "Dependencias OK"
    log_ok "Script: $VIDLOOP_SCRIPT"
    log_ok "CSV:    $CSV_FILE"

    # Crear directorio de logs
    mkdir -p "$LOG_DIR"
    log_ok "Logs en: $LOG_DIR"

    log_section "Leyendo RPis desde CSV"
    read_csv "$CSV_FILE"

    local total
    total=$(wc -l < "$_CSV_ENTRIES_FILE" | tr -d ' ')

    if [ "$total" -eq 0 ]; then
        log_error "No se encontraron RPis válidas en $CSV_FILE"
        exit 1
    fi

    log_ok "$total RPis cargadas"
    echo "$total" > "$_COUNTER_DIR/total"

    # DRY RUN: solo listar sin ejecutar
    if [[ "$DRY_RUN" == "true" ]]; then
        log_section "DRY RUN — solo listado (no se ejecuta nada)"
        printf "%-20s %-20s %-10s %-6s %-15s\n" "NOMBRE" "HOST" "USUARIO" "PUERTO" "WG_IP"
        printf '%.0s─' {1..75}; echo
        while IFS='|' read -r name host user pass port wg_ip; do
            printf "%-20s %-20s %-10s %-6s %-15s\n" "$name" "$host" "$user" "$port" "$wg_ip"
        done < "$_CSV_ENTRIES_FILE"
        rm -f "$_CSV_ENTRIES_FILE"
        echo
        log_ok "DRY_RUN=true — sin cambios realizados"
        exit 0
    fi

    log_section "Verificando conectividad con VPS"
    if [[ "$SKIP_WG" != "true" ]]; then
        if _vps "ip link show $VPS_WG_IF" &>/dev/null; then
            log_ok "VPS $VPS_IP alcanzable, interfaz $VPS_WG_IF activa"
        else
            log_warn "VPS $VPS_IP — interfaz $VPS_WG_IF NO activa"
            log_warn "WireGuard se configurará pero la interfaz RPi puede no levantar hasta hacer wg-quick up"
            log_warn "Para activar WG en VPS: ssh $VPS_USER@$VPS_IP 'wg-quick up $VPS_WG_IF'"
        fi
    else
        log_warn "SKIP_WG=true — WireGuard omitido"
    fi

    log_section "Iniciando deploy paralelo (MAX_PARALLEL=$MAX_PARALLEL)"
    echo "  Total: $total RPis | Reintentos: $RETRY_COUNT | Inicio: $(date)"
    echo

    declare -a PIDS=()

    while IFS='|' read -r name host user pass port wg_ip; do
        # Adquirir slot de semáforo (bloquea si ya hay MAX_PARALLEL jobs activos)
        _sem_acquire

        # Lanzar deploy en background
        deploy_with_retry "$name" "$host" "$user" "$pass" "$port" "$wg_ip" &
        PIDS+=($!)
    done < "$_CSV_ENTRIES_FILE"

    rm -f "$_CSV_ENTRIES_FILE"

    # Esperar todos los jobs
    for pid in "${PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # ── REPORTE FINAL ────────────────────────────────────────────
    local ok; ok=$(cat "$_COUNTER_DIR/ok")
    local fail; fail=$(cat "$_COUNTER_DIR/fail")

    log_section "RESUMEN FINAL"
    printf "  %-8s %s\n" "Total:" "$total"
    printf "  ${GREEN}%-8s %s${NC}\n" "Éxito:" "$ok"
    printf "  ${RED}%-8s %s${NC}\n" "Fallo:" "$fail"
    echo
    echo "  Logs completos: $LOG_DIR"

    if [ "$fail" -gt 0 ]; then
        echo
        log_warn "RPis con errores:"
        grep "^FAIL" "$_RESULTS_FILE" | while IFS=$'\t' read -r status name host wg_ip; do
            echo "    ✗ $name ($host) → $LOG_DIR/${name}.log"
        done
    fi

    if [ "$ok" -gt 0 ]; then
        echo
        log_ok "RPis desplegadas correctamente:"
        grep "^OK" "$_RESULTS_FILE" | while IFS=$'\t' read -r status name host wg_ip; do
            echo "    ✓ $name  $host  WG:$wg_ip"
        done
    fi

    echo
    [ "$fail" -eq 0 ] && log_ok "Deploy completado sin errores." || log_warn "Deploy finalizado con $fail errores."

    # Limpiar directorio de semáforo
    rm -rf "$_SEM_DIR"

    return "$fail"
}

main "$@"
