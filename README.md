# Sistema de Videoloops para Raspberry Pi

Solución profesional para reproducción automática y continua de videos en pantallas, ideal para puntos de venta, exhibiciones, ferias y señalización digital.  
Desarrollado por **Ignacio Manuel Centeno** (Desarrollador de Software), con el aval de **44 Contenidos**.

---

## ¿Qué es?

Este sistema convierte cualquier Raspberry Pi en un reproductor de videoloops plug & play, utilizando el software [VIDLOOP] y una configuración personalizada para máxima estabilidad y facilidad de uso.

---

## Características principales

- Instalación automática y rápida
- Reproducción continua de videos desde una carpeta local
- Configuración HDMI optimizada para evitar problemas de señal
- Personalización avanzada (OSD, fondo, colores, orden de reproducción, etc.)
- Listo para usar en entornos profesionales
- **Acceso remoto seguro mediante VPN (ZeroTier)**

---

## Instalación paso a paso

1. **Clonar el repositorio en la Raspberry Pi:**
   ```bash
   git clone <https://github.com/ignacentenox/VIDLOOP.git>
   cd <VIDLOOP>
   ```

2. **Dar permisos de ejecución al instalador:**
   ```bash
   chmod +x installvidloop44.sh
   ```

3. **Ejecutar el script de instalación:**
   ```bash
   ./installvidloop44.sh
   ```

   El script realiza automáticamente:
   - Actualización del sistema
   - Instalación de dependencias
   - Configuración de la salida HDMI
   - Instalación y configuración de pi_video_looper con parámetros personalizados
   - **Instalación de ZeroTier para acceso VPN**

4. **Reiniciar la Raspberry Pi:**
   ```bash
   sudo reboot
   ```

---

## Acceso remoto seguro (VPN con ZeroTier)

Para acceder remotamente a cada Raspberry Pi a través de una VPN privada y segura:

1. **Unir la Raspberry Pi a tu red ZeroTier:**  
   Después de la instalación y reinicio, ejecuta:
   ```bash
   sudo zerotier-cli join <ID_DE_TU_RED_ZEROTIER>
   ```
   Reemplaza `<ID_DE_TU_RED_ZEROTIER>` por el ID de tu red.

2. **Autoriza el dispositivo en el panel de ZeroTier:**  
   Ingresa a [ZeroTier Central](https://my.zerotier.com/) y autoriza la Raspberry Pi en tu red.

3. **Listo!**  
   Ahora podes acceder a la Raspberry Pi desde cualquier lugar a través de la VPN.

---

## Uso

- Coloca tus videos en la carpeta `/home/pi/VIDLOOP44` (créala si no existe).
- Los videos se reproducirán automáticamente en loop al iniciar la Raspberry Pi.
- Puedes personalizar la configuración editando el archivo `video_looper.ini` antes de la instalación.

---

## Soporte y contacto

Desarrollado por:  
**Ignacio Manuel Centeno**  
Desarrollador de Software  
[ignacenteno46@gmail.com](mailto:ignacenteno46@gmail.com)

Proyecto avalado por:  
**44 Contenidos**  
Soluciones audiovisuales y digitales

---

¿Listo para profesionalizar la comunicación visual de tu empresa?  
¡Consultanos para implementaciones a medida!
