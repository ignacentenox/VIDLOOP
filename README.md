# VIDLOOP

Instalador para Raspberry Pi OS Lite Legacy Buster (`2022-01-28-raspios-buster-armhf-lite`) que reproduce imagenes y videos en loop sin convertir fotos a MP4.

Base operativa:

- Videos: `omxplayer`
- Imagenes: `fbi` directo sobre framebuffer
- Servicio: `video_looper`
- VPN: ZeroTier
- Carpeta de medios: `/home/vidloop/VIDLOOP44`

## Formatos soportados

Videos:

- `.mp4`
- `.m4v`
- `.mov`
- `.mkv`
- `.avi`
- `.mpg`
- `.mpeg`
- `.ts`
- `.m2ts`

Imagenes:

- `.jpg`
- `.jpeg`
- `.png`
- `.gif`
- `.bmp`

## Instalacion rapida

En la Raspberry recien instalada, copia esta carpeta `vidloop-sh` y ejecuta:

```bash
cd vidloop-sh
sudo ./install.sh --zt-network TU_NETWORK_ID --auto-reboot
```

Si despues subis este proyecto a GitHub, el flujo queda:

```bash
sudo apt-get update
sudo apt-get install -y git
git clone URL_DEL_REPO
cd vidloop-sh
sudo ./install.sh --zt-network TU_NETWORK_ID --auto-reboot
```

El `network ID` de ZeroTier debe tener 16 caracteres hexadecimales. Despues del `join`, hay que autorizar el nodo en ZeroTier Central.

## Instalacion con variables

```bash
sudo VIDLOOP_ZT_NETWORK_ID=8056c2e21c000001 \
     VIDLOOP_USER=vidloop \
     VIDLOOP_PASSWORD=4455 \
     VIDLOOP_IMAGE_DURATION_SEC=20 \
     VIDLOOP_AUTO_REBOOT=true \
     ./install.sh
```

## Uso

Subi imagenes y videos a:

```bash
/home/vidloop/VIDLOOP44
```

Reinicia el loop:

```bash
sudo systemctl restart video_looper
```

Ver logs:

```bash
sudo journalctl -u video_looper -f
sudo tail -f /var/log/vidloop44.log
```

## Configuracion

El archivo principal queda en:

```bash
/etc/default/vidloop
```

Variables utiles:

```bash
VIDLOOP_MEDIA_DIR="/home/vidloop/VIDLOOP44"
VIDLOOP_IMAGE_DURATION_SEC="20"
VIDLOOP_WAIT_SEC="0"
VIDLOOP_VIDEO_ASPECT_MODE="fill"
VIDLOOP_SINGLE_VIDEO_LOOP="true"
```

Valores posibles para `VIDLOOP_VIDEO_ASPECT_MODE`, segun `omxplayer`:

- `fill`
- `letterbox`
- `stretch`

## HDMI y pantalla

El instalador refuerza la salida HDMI y evita que la consola apague la pantalla:

- Fuerza HDMI aunque la pantalla no responda a tiempo: `hdmi_force_hotplug=1`
- Fuerza audio/modo HDMI: `hdmi_drive=2`
- Define modo 1080p60 por defecto: `hdmi_group=1`, `hdmi_mode=16`
- Sube potencia HDMI legacy: `config_hdmi_boost=7`
- Desactiva blanking HDMI/consola: `hdmi_blanking=0`, `consoleblank=0`
- Silencia el arranque: `quiet`, `splash`, `logo.nologo`, `loglevel=0`, `systemd.show_status=false`, `udev.log_priority=3`
- Oculta cursor de consola: `vt.global_cursor_default=0`
- Desactiva `getty` en `tty1` para que no aparezca el prompt de login encima del loop
- Instala `vidloop-boot-blackout.service` para limpiar la pantalla y dejarla negra antes de iniciar el reproductor
- Instala `vidloop-display-guard.service` para reaplicar `setterm -blank 0 -powerdown 0 -powersave off`
- Instala `vidloop-hdmi-keepalive.service` para recuperar HDMI con `tvservice`, refrescar framebuffer y reiniciar `video_looper` si la pantalla vuelve

Por defecto deja la pantalla negra `2` segundos antes del reproductor. Se puede ajustar:

```bash
sudo VIDLOOP_BOOT_BLACK_DELAY_SEC=4 ./install.sh --zt-network TU_NETWORK_ID
```

Servicios de pantalla:

```bash
sudo systemctl status vidloop-boot-blackout
sudo systemctl status vidloop-display-guard
sudo systemctl status vidloop-hdmi-keepalive
```

Pantallas con EDID inestable:

```bash
sudo VIDLOOP_HDMI_IGNORE_EDID=true ./install.sh --zt-network TU_NETWORK_ID --auto-reboot
```

Usa `VIDLOOP_HDMI_IGNORE_EDID=true` solo si la pantalla no levanta señal o entrega mal el EDID. Fuerza el modo configurado y puede dejar sin imagen a pantallas que no soporten ese modo.

Cambiar resolucion HDMI:

```bash
sudo VIDLOOP_HDMI_GROUP=1 VIDLOOP_HDMI_MODE=4 ./install.sh --zt-network TU_NETWORK_ID
```

## Compatibilidad con dashboard

El servicio se llama `video_looper`, asi que los comandos existentes del dashboard pueden seguir usando:

```bash
sudo systemctl restart video_looper
```

El log principal queda en:

```bash
/var/log/vidloop44.log
```

## Diferencia con pi_video_looper

`pi_video_looper` soporta videos y tambien tiene un modo `image_player`, pero el modo de imagen es separado del modo de video. Este instalador evita esa limitacion con un reproductor mixto: detecta cada archivo por extension y usa el backend correcto para cada caso.

## Notas para Buster Lite

La imagen recomendada por Adafruit para `pi_video_looper` es:

```text
https://downloads.raspberrypi.com/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2022-01-28/2022-01-28-raspios-buster-armhf-lite.zip
```

El instalador ajusta repositorios legacy/archive si detecta `buster`, porque esa imagen puede fallar con repositorios movidos o metadata expirada.
