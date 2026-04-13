#!/bin/bash

################################################################################
# autopush.sh - Commit y push automático a GitHub después de cambios
#
# USO: ./autopush.sh "mensaje de commit"
# EJEMPLO: ./autopush.sh "feat: agregar soporte WireGuard master download"
#
# Script que:
# 1. Verifica cambios no commiteados
# 2. Agrega todos los cambios
# 3. Realiza commit con mensaje
# 4. Hace push a main
#
# NOTA: Requiere acceso a GitHub configurado con SSH o HTTPS credenciales
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMIT_MSG="${1:-fix: actualización automática VIDLOOP}"

echo -e "${BLUE}[*] === AUTO-PUSH SCRIPT ===${NC}"
echo -e "${BLUE}[*] Repositorio: $REPO_DIR${NC}"
echo

# Cambiar a directorio del repositorio
cd "$REPO_DIR"

# Verificar que es un repo git
if [ ! -d .git ]; then
  echo -e "${RED}[ERROR] No es un repositorio git${NC}"
  exit 1
fi

# Verificar cambios
CHANGES=$(git status --porcelain)

if [ -z "$CHANGES" ]; then
  echo -e "${YELLOW}[*] No hay cambios por commitear${NC}"
  exit 0
fi

echo -e "${BLUE}[*] Cambios detectados:${NC}"
echo "$CHANGES" | sed 's/^/  /'
echo

# Agregar todos los cambios
echo -e "${YELLOW}[*] Agregando cambios...${NC}"
git add -A
echo -e "${GREEN}[✓] Cambios agregados${NC}"

# Crear commit
echo -e "${YELLOW}[*] Creando commit: '$COMMIT_MSG'${NC}"
git commit -m "$COMMIT_MSG" || {
  echo -e "${RED}[ERROR] Fallo al crear commit${NC}"
  exit 1
}
echo -e "${GREEN}[✓] Commit creado${NC}"

# Hacer push
echo -e "${YELLOW}[*] Haciendo push a GitHub...${NC}"
if git push origin main 2>&1; then
  echo -e "${GREEN}[✓] Push a main completado${NC}"
elif git push origin master 2>&1; then
  echo -e "${GREEN}[✓] Push a master completado${NC}"
else
  echo -e "${RED}[ERROR] Fallo al hacer push${NC}"
  exit 1
fi

echo
echo -e "${GREEN}[✓] === AUTO-PUSH COMPLETADO ===${NC}"
echo -e "${BLUE}[INFO] Verificar en: https://github.com/ignacentenox/VIDLOOP${NC}"
echo
