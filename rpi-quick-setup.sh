#!/usr/bin/env bash
set -euo pipefail

# ================================================================
#  VIDLOOP RPi QUICK SETUP
#  Configura usuario, password, SSH y descargar VIDLOOP-V3.0.sh
#  Se ejecuta DENTRO de la RPi después del primer boot
#  Desarrollado por IGNACE — Powered by 44 Contenidos
# ================================================================
#
# USO (ejecutar directamente desde SSH de la RPi):
#   curl -fsSL https://raw.githubusercontent.com/ignacentenox/VIDLOOP/main/rpi-quick-setup.sh | bash
#
# O manualmente:
#   wget https://raw.githubusercontent.com/ignacentenox/VIDLOOP/main/rpi-quick-setup.sh -O /tmp/setup.sh
#   bash /tmp/setup.sh
#
# PARÁMETROS (vía env vars):
#   NEW_USER       Usuario SSH nuevo              (default: vidloop)
#   NEW_PASS       Password nuevo                 (default: 4455)
#   REMOVE_PI_USER  true = borrar usuario 'pi'    (default: true)
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
NEW_USER="${NEW_USER:-vidloop}"
NEW_PASS="${NEW_PASS:-4455}"
REMOVE_PI_USER="${REMOVE_PI_USER:-true}"

# ── BANNER ───────────────────────────────────────────────────────
echo -e "\n${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║     VIDLOOP RPi Quick Setup v1.0             ║"
echo "  ║     Powered by 44 Contenidos — IGNACE        ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}\n"

# ── VERIFICAR PRIVILEGIOS ────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
   log_error "Este script DEBE ejecutarse como root (usa: sudo bash ...)"
   exit 1
fi

# ── PASO 1: ACTUALIZAR SISTEMA ───────────────────────────────────
log_step "1/5 Actualizar sistema"
log_info "apt-get update && apt-get upgrade..."
apt-get update >/dev/null 2>&1
apt-get upgrade -y >/dev/null 2>&1
log_ok "Sistema actualizado"

# ── PASO 2: CREAR USUARIO NUEVO ──────────────────────────────────
log_step "2/5 Crear usuario '${NEW_USER}'"

if id "${NEW_USER}" &>/dev/null; then
    log_warn "Usuario ${NEW_USER} ya existe"
else
    log_info "Creando usuario ${NEW_USER}..."
    useradd -m -s /bin/bash -G sudo "${NEW_USER}" 2>/dev/null || true
    
    # Establecer password
    echo "${NEW_USER}:${NEW_PASS}" | chpasswd
    log_ok "Usuario ${NEW_USER} creado con password configurado"
fi

# Permitir NOPASSWD sudo para este usuario (opcional)
if ! grep -q "^${NEW_USER} ALL=" /etc/sudoers; then
    echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    log_ok "Permisos sudo sin password configurados"
fi

# ── PASO 3: CONFIGURAR SSH ───────────────────────────────────────
log_step "3/5 Configurar SSH"

log_info "Habilitando SSH daemon..."
systemctl start ssh
systemctl enable ssh
systemctl is-active --quiet ssh && log_ok "SSH activo y habilitado"

# ── PASO 4: ELIMINAR USUARIO 'pi' (OPCIONAL) ────────────────────
log_step "4/5 Limpieza de usuarios"

if [[ "$REMOVE_PI_USER" == "true" ]] && id "pi" &>/dev/null; then
    log_warn "Eliminando usuario 'pi'..."
    userdel -r pi 2>/dev/null || log_warn "Usuario pi no pudo eliminarse (podría estar en uso)"
    log_ok "Usuario pi removido"
else
    log_info "Usuario pi conservado"
fi

# ── PASO 5: INFORMACIÓN FINAL ────────────────────────────────────
log_step "5/5 Setup completado"

HOSTNAME=$(hostname)
IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}${BOLD}✓ RPi configurada y lista para deploy${NC}"
echo ""
echo -e "  ${CYAN}Información de acceso:${NC}"
echo -e "    Hostname  : ${BOLD}${HOSTNAME}${NC}"
echo -e "    IP        : ${BOLD}${IP}${NC}"
echo -e "    Usuario   : ${BOLD}${NEW_USER}${NC}"
echo -e "    Password  : ${BOLD}${NEW_PASS}${NC}"
echo -e "    SSH       : ${BOLD}Activo${NC}"
echo ""
echo -e "  ${CYAN}Próximo paso desde tu Mac:${NC}"
echo -e "    ${BOLD}./deploy-vidloop.sh rpis.csv${NC}"
echo ""
echo -e "  ${CYAN}O conectar manualmente:${NC}"
echo -e "    ${BOLD}ssh ${NEW_USER}@${IP}${NC}"
echo ""
