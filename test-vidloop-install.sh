#!/usr/bin/env bash

# VIDLOOP Validation Script v1.1

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}     VALIDACIÓN VIDLOOP V3.0 POST-INSTALL      ${NC}"
echo -e "${BLUE}================================================${NC}"

ERRORS=0
WARNINGS=0

CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"

# ================================================================
# 1. Validar usuario vidloop
# ================================================================
echo -e "\n${BLUE}[1] Usuario vidloop${NC}"
if id -u vidloop >/dev/null 2>&1; then
    VIDLOOP_HOME=$(eval echo ~vidloop)
    echo -e "    ${CHECK} Usuario vidloop existe (home: $VIDLOOP_HOME)"
    
    GROUPS=$(id vidloop | grep -o 'groups=[^)]*' | cut -d'=' -f2)
    if echo "$GROUPS" | grep -q "sudo"; then
        echo -e "    ${CHECK} Usuario vidloop tiene permisos sudo"
    fi
    
    if echo "$GROUPS" | grep -q "audio"; then
        echo -e "    ${CHECK} Usuario vidloop en grupo audio (radio ready)"
    fi
else
    echo -e "    ${CROSS} Usuario vidloop NO EXISTE"
    ERRORS=$((ERRORS + 1))
fi

# ================================================================
# 2. Validar directorio VIDLOOP44
# ================================================================
echo -e "\n${BLUE}[2] Directorio de videos (VIDLOOP44)${NC}"
VIDEO_DIR="/home/vidloop/VIDLOOP44"
if [ -d "$VIDEO_DIR" ]; then
    echo -e "    ${CHECK} Directorio $VIDEO_DIR existe"
    
    PERMS=$(stat -c "%a" "$VIDEO_DIR" 2>/dev/null || stat -f "%A" "$VIDEO_DIR" 2>/dev/null || echo "error")
    if [ "$PERMS" = "775" ]; then
        echo -e "    ${CHECK} Permisos correctos: 775 (escribible)"
    elif [ "$PERMS" = "755" ]; then
        echo -e "    ${WARN} Permisos restringidos: 755"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "    ${WARN} Permisos: $PERMS"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "    ${CROSS} Directorio NO EXISTE"
    ERRORS=$((ERRORS + 1))
fi

# ================================================================
# 3. Validar servicio video_looper
# ================================================================
echo -e "\n${BLUE}[3] Servicio video_looper${NC}"
if sudo systemctl is-active --quiet video_looper 2>/dev/null; then
    echo -e "    ${CHECK} Servicio video_looper está ACTIVO"
elif command -v supervisorctl >/dev/null 2>&1 && sudo supervisorctl status video_looper 2>/dev/null | grep -q 'RUNNING'; then
    echo -e "    ${CHECK} Servicio video_looper RUNNING (supervisor)"
else
    echo -e "    ${CROSS} Servicio video_looper NO ESTÁ ACTIVO"
    ERRORS=$((ERRORS + 1))
fi

# ================================================================
# 4. Validar usuario pi
# ================================================================
echo -e "\n${BLUE}[4] Usuario pi y grupo vidloop${NC}"
if id -u pi >/dev/null 2>&1; then
    echo -e "    ${CHECK} Usuario pi existe"
    
    if id pi 2>/dev/null | grep -q "vidloop"; then
        echo -e "    ${CHECK} Usuario pi está en grupo vidloop"
    else
        echo -e "    ${WARN} Usuario pi NO está en grupo vidloop"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "    ${WARN} Usuario pi no existe"
    WARNINGS=$((WARNINGS + 1))
fi

# ================================================================
# 5. Validar WireGuard
# ================================================================
echo -e "\n${BLUE}[5] Configuración WireGuard${NC}"
if [ -f /etc/wireguard/wg0.conf ]; then
    echo -e "    ${CHECK} Config WireGuard existe"
    
    if sudo ip link show wg0 >/dev/null 2>&1; then
        echo -e "    ${CHECK} Interfaz wg0 está UP"
        WG_IP=$(sudo ip -4 addr show wg0 2>/dev/null | awk '/inet /{print $2}' | head -n1)
        if [ -n "$WG_IP" ]; then
            echo -e "    ${CHECK} IP asignada: $WG_IP"
        fi
    else
        echo -e "    ${WARN} Interfaz wg0 NO está UP"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "    ${WARN} WireGuard no configurado"
    WARNINGS=$((WARNINGS + 1))
fi

# ================================================================
# 6. Validar SSH
# ================================================================
echo -e "\n${BLUE}[6] OpenSSH${NC}"
if sudo systemctl is-active --quiet ssh 2>/dev/null || sudo systemctl is-active --quiet sshd 2>/dev/null; then
    echo -e "    ${CHECK} SSH está activo"
else
    echo -e "    ${WARN} SSH no activo"
    WARNINGS=$((WARNINGS + 1))
fi

# ================================================================
# RESUMEN FINAL
# ================================================================
echo
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}                   RESUMEN                       ${NC}"
echo -e "${BLUE}================================================${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ ESTADO GENERAL: LISTO PARA PRODUCCIÓN${NC}"
else
    echo -e "${RED}✗ ERRORES ENCONTRADOS: $ERRORS${NC}"
fi

if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠ ADVERTENCIAS: $WARNINGS${NC}"
fi

echo

exit $ERRORS
