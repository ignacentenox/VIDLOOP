# VIDLOOP

Sistema de gestión y reproducción de video para pantallas digitales instaladas en Raspberry Pi.

## ¿Qué es VIDLOOP?

VIDLOOP convierte cualquier Raspberry Pi en un reproductor de video profesional para señalización digital. Permite administrar el contenido desde un panel central y actualizar los videos de forma remota en múltiples dispositivos.

---

## Características

- Reproducción continua en loop de videos MP4
- Conversión automática de imágenes a video
- Gestión remota de contenido
- Soporte para múltiples dispositivos
- Conectividad VPN para acceso seguro

---

## Requisitos

- Raspberry Pi (2, 3 o 4)
- Raspberry Pi OS Lite Legacy (Buster, armhf)
- Monitor o pantalla HDMI
- Conexión a internet

---

## Instalación rápida

Flashear la SD con la imagen oficial, arrancar la Raspberry con internet y ejecutar:

```bash
curl -fL https://github.com/ignacentenox/VIDLOOP/archive/refs/heads/main.zip -o VIDLOOP.zip
unzip -q VIDLOOP.zip
cd VIDLOOP-main
chmod +x VIDLOOP-V3.0.sh
sudo ./VIDLOOP-V3.0.sh
```

El instalador configura todo automáticamente y reinicia el equipo al finalizar.

---

## Imagen compatible

Para garantizar compatibilidad se recomienda la imagen oficial Buster Lite:

[Raspberry Pi OS Buster Lite (2022-01-28)](https://downloads.raspberrypi.com/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2022-01-28/2022-01-28-raspios-buster-armhf-lite.zip)

---

## Licencia

Uso interno — 44 Contenidos. Todos los derechos reservados.
