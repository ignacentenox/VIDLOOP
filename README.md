# VIDLOOP V3

Sistema one-shot para Raspberry Pi que instala y configura `pi_video_looper`, optimiza HDMI, habilita control remoto (VPN opcional) y deja servicios listos para operación continua.

Base de reproducción:
- https://videolooper.de/
- https://github.com/adafruit/pi_video_looper.git

## Compatibilidad importante

`pi_video_looper` depende de `omxplayer`, por lo que la base recomendada es **Raspberry Pi OS Lite Legacy (armhf)**.

Imagen de referencia funcional:
- https://downloads.raspberrypi.com/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2022-01-28/2022-01-28-raspios-buster-armhf-lite.zip

Notas:
- Evitar imágenes modernas no-legacy para despliegues críticos de videoloop.
- Raspberry Pi 5 no es objetivo recomendado para este stack heredado.
- En Buster Legacy, este proyecto agrega automáticamente el repo legacy de Raspbian cuando hace falta.

## Estado actual del proyecto

Este repositorio ya incluye:
- Instalador principal: `VIDLOOP-V3.0.sh`
- Config de reproducción: `video_looper.ini`
- Kit de imagen maestra: `image-kit/`
- Workflow para build y publicación de imagen en Releases: `.github/workflows/build-image-release.yml`

## Instalación rápida (SD vacía)

1. Flashear Raspberry Pi OS **Lite Legacy (armhf)** en la SD.
2. Arrancar la Raspberry con internet.
3. Copiar la carpeta `VIDLOOP` a la Raspberry (pendrive, SCP o descarga ZIP).
4. Ejecutar:

### Opción A: con git disponible

```bash
git clone https://github.com/ignacentenox/VIDLOOP.git
cd VIDLOOP
chmod +x VIDLOOP-V3.0.sh
sudo ./VIDLOOP-V3.0.sh
```

### Opción B: sin git (recomendada para tu caso)

```bash
cd ~
curl -fL https://github.com/ignacentenox/VIDLOOP/archive/refs/heads/main.zip -o VIDLOOP.zip
unzip -q VIDLOOP.zip
cd VIDLOOP-main
chmod +x VIDLOOP-V3.0.sh
sudo ./VIDLOOP-V3.0.sh
```

El instalador V3 está en modo no interactivo por defecto y deja el equipo operativo.

## Qué hace VIDLOOP-V3.0.sh

- `apt update` y `apt full-upgrade` (por defecto)
- instala dependencias base
- instala `pi_video_looper` si no está presente
- instala `pi_video_looper` con opción `no_hello_video` por defecto
- si `git` no existe, descarga e instala `pi_video_looper` por ZIP automáticamente
- aplica `video_looper.ini` en `/opt/video_looper/video_looper.ini`
- ajusta ruta de videos a `/home/vidloop/VIDLOOP44`
- habilita y reinicia `video_looper`
- aplica override `systemd` para recuperación automática del servicio
- configura HDMI básico y keepalive (si `tvservice` está disponible)
- configura SSH endurecido (sin root, password auth desactivado por defecto)
- soporta ZeroTier (APT)
- soporta WireGuard opcional
- reinicia automáticamente al finalizar (por defecto)

## Referencia oficial de pi_video_looper y cómo se aplica acá

El README oficial indica:
- usar Raspberry Pi OS Lite Legacy (Buster)
- en algunos casos agregar repo `legacy.raspbian.org`
- instalar con `install.sh` (opcional `no_hello_video`)
- considerar que una reinstalación puede sobrescribir `/boot/video_looper.ini`

En VIDLOOP V3 eso ya está contemplado:
- detecta Buster y agrega repo legacy si hace falta
- instala con `no_hello_video` por defecto
- hace backup de `/boot/video_looper.ini` antes de instalar si existe
- vuelve a aplicar la configuración local del proyecto luego de instalar

## Variables de entorno útiles

### Flujo general
- `VIDLOOP_AUTO_REBOOT=false` evita reinicio al final.
- `VIDLOOP_FULL_UPGRADE=false` omite full-upgrade.
- `VIDLOOP_AGGRESSIVE_TUNING=true` activa perfil agresivo de tuning.
- `ENABLE_SSH_PASSWORD_AUTH=true` habilita autenticación por password en SSH.
- `VIDLOOP_ENABLE_MEDIA_NORMALIZER=true` convierte imagenes en `VIDLOOP44` a MP4 automaticamente.
- `VIDLOOP_IMAGE_DURATION_SEC=20` define duracion por foto convertida (default 20s).
- `VIDLOOP_IMAGE_SCAN_INTERVAL_MIN=1` define cada cuantos minutos escanear nuevas imagenes.

### WireGuard opcional
- `ENABLE_WIREGUARD=true`
- `VIDLOOP_WG_INTERFACE=wg0`
- `VIDLOOP_WG_CONFIG_B64=<contenido base64 de wg0.conf>`
- `VIDLOOP_WG_CONFIG_TEXT='<contenido completo de wg0.conf>'`
- `VIDLOOP_WG_CONFIG_FILE=/ruta/local/wg0.conf`

Ejemplo WireGuard:

```bash
WG_B64="$(base64 -w0 wg0.conf 2>/dev/null || base64 < wg0.conf | tr -d '\n')"
sudo ENABLE_WIREGUARD=true VIDLOOP_WG_CONFIG_B64="$WG_B64" ./VIDLOOP-V3.0.sh
```

## Control remoto desde dashboard

Comandos recomendados para tus botones:

- Reiniciar RPi:

```bash
sudo reboot
```

- Reiniciar sistema de video:

```bash
sudo systemctl restart video_looper
```

Verificación rápida de estado:

```bash
sudo systemctl is-active video_looper
sudo systemctl status video_looper --no-pager -l
```

## Estructura del repositorio

- `VIDLOOP-V3.0.sh`: instalador principal one-shot.
- `video_looper.ini`: plantilla de configuración de reproducción.
- `image-kit/README.md`: guía completa de imagen maestra.
- `image-kit/install-firstboot-service.sh`: instala servicio one-shot de primer arranque.
- `image-kit/preclone-cleanup.sh`: limpieza de identidad antes de clonar SD.
- `image-kit/firstboot-init.sh`: inicialización en primer arranque del clon.
- `image-kit/build-master-image.sh`: build manual de `.img.xz` en Linux.
- `image-kit/ci/build-release-image.sh`: build de imagen para CI.
- `.github/workflows/build-image-release.yml`: workflow para publicar imagen en Releases.

## Imagen maestra manual

Flujo resumido:

1. En la Raspberry maestra:

```bash
sudo ./image-kit/install-firstboot-service.sh
sudo ./image-kit/preclone-cleanup.sh
sudo poweroff
```

2. En host Linux con la SD conectada:

```bash
sudo ./image-kit/build-master-image.sh /dev/sdX vidloop-v3-master-YYYYMMDD
```

Resultado:
- `vidloop-v3-master-YYYYMMDD.img.xz`
- `vidloop-v3-master-YYYYMMDD.img.xz.sha256`

## Build y publicación automática en GitHub Releases

Desde GitHub Actions:

1. Abrir Actions.
2. Ejecutar `Build VIDLOOP Image Release`.
3. Cargar `release_tag` (ejemplo: `v3.0.0-image1`).
4. Esperar build.

Artifacts publicados en la Release:
- `*.img.xz`
- `*.img.xz.sha256`

La imagen generada ejecuta autoprovisioning en el primer arranque usando `VIDLOOP-V3.0.sh`.

## Notas operativas

- Usuario SSH por defecto: `vidloop`
- Password SSH por defecto: `4455`
- Carpeta de videos operativa: `/home/vidloop/VIDLOOP44`
- Servicio principal: `video_looper`
- Keepalive HDMI: `hdmi-keepalive` (si aplica en la imagen/stack)
- Credenciales y metadatos locales: `/root/.vidloop/admin_credentials.txt`

## Licencia

Ver archivo `LICENSE` si corresponde en el repositorio.
