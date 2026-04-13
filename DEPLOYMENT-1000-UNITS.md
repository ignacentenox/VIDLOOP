# VIDLOOP V3.0 - Despliegue Masivo en 1000 RPis

## Visión General

VIDLOOP V3.0 está diseñado como **ONE-SHOT INSTALLER** que funciona de forma completamente idempotente. Esto significa que:

- ✅ Se puede ejecutar múltiples veces sin problemas
- ✅ Es tolerante a fallos de red
- ✅ Soporta actualizaciones sin reinstalar
- ✅ Todo está integrado en UN ÚNICO archivo: `VIDLOOP-V3.0.sh`
- ✅ WireGuard puede configurarse automáticamente

## Preparación Pre-Despliegue

### 1. Preparar Imagen Base (una vez)

```bash
# En tu Mac LOCAL
cd ~/Documents/PROG/VIDLOOP/VIDLOOP_REPO

# 1. Flashear Raspberry Pi OS Lite Legacy (Buster armhf) en una SD
# Descargar de: https://downloads.raspberrypi.com/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2022-01-28/

# 2. Copiar VIDLOOP-V3.0.sh a la SD antes de bootear la RPi
# (via pendrive o SCP después de bootear con Ethernet)

# 3. En la RPi, ejecutar:
sudo ./VIDLOOP-V3.0.sh
```

### 2. Imagen Maestra (opcional pero recomendado para 1000 units)

Una vez que UNA RPi debe quedar perfecta, puedes hacer una imagen clonada:

```bash
# En la RPi perfecta:
sudo ./image-kit/install-firstboot-service.sh
sudo ./image-kit/preclone-cleanup.sh
sudo poweroff

# En host Linux (con SD conectada):
sudo ./image-kit/build-master-image.sh /dev/sdX vidloop-v3-master-prod

# Resultado: vidloop-v3-master-prod.img.xz
# Flashear esa imagen en las 1000 SDs
```

## Despliegue Estándar (Sin VPN)

### Opción 1: Instalación Manual en RPi

```bash
# En la RPi, descargar y ejecutar:
cd ~
curl -fL https://github.com/ignacentenox/VIDLOOP/archive/refs/heads/main.zip -o VIDLOOP.zip
unzip -q VIDLOOP.zip
cd VIDLOOP-main
chmod +x VIDLOOP-V3.0.sh
sudo ./VIDLOOP-V3.0.sh
```

### Opción 2: Instalación Remota (si tienes acceso SSH)

```bash
# Desde tu Mac o servidor:
#!/bin/bash

RPI_LIST="192.168.1.100 192.168.1.101 192.168.1.102 ... (hasta 1000)"

for RPI_IP in $RPI_LIST; do
  echo "[*] Instalando en $RPI_IP..."
  sshpass -p 4455 ssh -o StrictHostKeyChecking=no vidloop@$RPI_IP << 'INSTALL_CMD'
    cd ~ && \
    curl -fL https://github.com/ignacentenox/VIDLOOP/archive/refs/heads/main.zip -o VIDLOOP.zip && \
    unzip -q VIDLOOP.zip && \
    cd VIDLOOP-main && \
    chmod +x VIDLOOP-V3.0.sh && \
    sudo ./VIDLOOP-V3.0.sh
INSTALL_CMD
  
  sleep 5
done
```

## Despliegue con WireGuard (VPN Centralizada)

### Archivos Clave

- `VIDLOOP-V3.0.sh` - Instalador principal (TODO integrado)
- `generate-wg-peer.sh` - Genera configuración en VPS (ejecutar UNA VEZ)
- `wireguard-setup-master.sh` - Orqueta todo automáticamente

### Flujo Completo (Ejemplo para TOTEM LANSER 2)

#### PASO 1: Generar configuración en VPS (UNA VEZ)

```bash
# En VPS (82.25.77.55), ejecutar:
curl -fL https://raw.githubusercontent.com/ignacentenox/VIDLOOP/main/generate-wg-peer.sh | bash

# Salida: /tmp/wireguard-totem-XXXX/wg0.conf
# Esta configuración se guarda automáticamente en /tmp/
```

#### PASO 2: Descargar automáticamente en RPi

Opción A: Con WireGuard centralizado en RPi

```bash
# En RPi, ejecutar:
sudo ENABLE_WIREGUARD=true VIDLOOP_DOWNLOAD_WG_FROM_VPS=1 \
  VIDLOOP_VPS_IP=82.25.77.55 \
  VIDLOOP_VPS_USER=root \
  VIDLOOP_VPS_PASS=Vidloop@44tech \
  ./VIDLOOP-V3.0.sh
```

Opción B: Descargar manualmente (más control)

```bash
# Desde tu Mac:
./wireguard-setup-master.sh 82.25.77.55 root Vidloop@44tech 192.168.0.53 vidloop 4455

# Esto:
# 1. Descarga wg0.conf desde VPS
# 2. Lo transfiere al RPi (192.168.0.53)
# 3. Aplica la configuración automáticamente
# 4. Verifica conectividad
```

## Escalabilidad: 1000 RPis

### Estrategia Recomendada

Para 1000 RPis distribuidas por Argentina:

#### Opción A: Instalación Local (recomendada)

1. **Preparar 1 imagen maestra perfecta** usando `image-kit/build-master-image.sh`
2. **Flashear esa imagen en lotes** (50, 100, 200 units a la vez)
3. **Cada RPi se arranca con Ethernet y se auto-configura** con VIDLOOP-V3.0.sh si es necesario

Ventajas:
- Rápido (imagen pre-optimizada)
- No require acceso SSH remoto
- Cada RPi es independiente

#### Opción B: Auto-Enrollment con WireGuard Central

1. **Generar UNA configuración WireGuard en VPS** (principal para todas)
2. **Instalar VIDLOOP en cada RPi con**:

```bash
sudo ENABLE_WIREGUARD=true \
  VIDLOOP_DOWNLOAD_WG_FROM_VPS=1 \
  VIDLOOP_VPS_IP=82.25.77.55 \
  ./VIDLOOP-V3.0.sh
```

3. **Centralizar gestión** desde dashboard (agro-gestion)

Ventajas:
- Control centralized desde dashboard
- Monitoreo 24/7 sin ir a cada ubicación
- Actualizaciones remotas posibles

### Archivos de Configuración por RPi

Cada RPi debería tener (guardados en `/root/.vidloop/`):

```
/root/.vidloop/admin_credentials.txt   # Usuario/pass SSH
/etc/wireguard/wg0.conf                # Config VPN (si aplica)
/home/vidloop/VIDLOOP44/               # Videos y media
/.hostname                              # Nombre único
```

## Monitoreo Post-Despliegue

### Verificar instalación en RPi

```bash
# SSH a RPi
ssh vidloop@192.168.0.XX

# Verificar servicios críticos
sudo systemctl status video_looper
sudo systemctl status ssh
sudo systemctl status zerotier-one     # Si está habilitado
sudo wg show wg0                        # Si WireGuard está activo

# Verificar permisos VIDLOOP44
ls -la /home/vidloop/VIDLOOP44

# Ver logs
sudo journalctl -u video_looper -n 50
```

### Script de Verificación Remota (para 1000 units)

```bash
#!/bin/bash

RPI_LIST="192.168.1.100 192.168.1.101 ... (1000 IPs)"

for RPI_IP in $RPI_LIST; do
  STATUS=$(sshpass -p 4455 ssh -o ConnectTimeout=3 \
    vidloop@$RPI_IP "sudo systemctl is-active video_looper" 2>/dev/null || echo "DOWN")
  
  [ "$STATUS" = "active" ] && \
    echo "[✓] $RPI_IP - OK" || \
    echo "[✗] $RPI_IP - PROBLEMA"
done
```

## Actualizaciones

### Actualizar VIDLOOP-V3.0.sh en Repo

1. Hacer cambios en el script
2. Ejecutar autopush:

```bash
chmod +x autopush.sh
./autopush.sh "feat: mejorar estabilidad WireGuard"
```

3. El cambio se pushea automáticamente a GitHub
4. **Cada RPi puede actualizar**:

```bash
cd ~/VIDLOOP-main && git pull && sudo ./VIDLOOP-V3.0.sh
```

## Variables de Entorno Disponibles

```bash
# General
VIDLOOP_NONINTERACTIVE=true              # Modo no interactivo (default)
VIDLOOP_AUTO_REBOOT=true                 # Reiniciar después de install
VIDLOOP_FULL_UPGRADE=true                # apt full-upgrade

# WireGuard
ENABLE_WIREGUARD=true                    # Habilitar WireGuard (default)
VIDLOOP_WG_INTERFACE=wg0                 # Nombre interfaz
VIDLOOP_DOWNLOAD_WG_FROM_VPS=1           # Descargar desde VPS
VIDLOOP_VPS_IP=82.25.77.55               # IP VPS
VIDLOOP_VPS_USER=root                    # Usuario VPS
VIDLOOP_VPS_PASS=Vidloop@44tech           # Password VPS
VIDLOOP_WG_CONFIG_FILE=/path/to/wg0.conf # Archivo local
VIDLOOP_WG_CONFIG_B64=...                # Base64 del config
VIDLOOP_WG_CONFIG_TEXT='...'             # Config como texto

# Media normalizer
VIDLOOP_ENABLE_MEDIA_NORMALIZER=true     # Convertir fotos a MP4
VIDLOOP_IMAGE_DURATION_SEC=20            # Segundos por foto
VIDLOOP_IMAGE_SCAN_INTERVAL_MIN=1        # Intervalo scan

# SSH
ENABLE_SSH_PASSWORD_AUTH=true            # Password auth (default)

# Tuning
VIDLOOP_AGGRESSIVE_TUNING=false          # Overclock (no recomendado para producción)
```

## Checklist Final (1000 RPis)

- [ ] Imagen maestra creada y testeada
- [ ] VIDLOOP-V3.0.sh subido a GitHub
- [ ] WireGuard en VPS configurado
- [ ] VPS credentials documentadas seguramente
- [ ] Primeras 10 RPis instaladas y testeadas
- [ ] Dashboard centralizado alcanza todas las RPis
- [ ] Monitoreo automatizado de 1000 units
- [ ] Plan B para fallos de red
- [ ] Recovery procedure dokumentado

## Soporte

Para issues:

1. Revisar logs en RPi: `sudo journalctl -u video_looper -n 100`
2. Verificar conectividad: `ping 8.8.8.8`
3. Revisar SSH: `sudo systemctl status ssh`
4. Si WireGuard: `sudo wg show` y `ping 10.0.0.1`
5. Reportar issue en GitHub dengan output de logs

---

**Última actualización**: 2026-04-13
**Version**: VIDLOOP V3.0
**Autor**: IGNACE (ignacentenox)
