# VIDLOOP 2.0 - Sistema Avanzado de Videoloops para Raspberry Pi

Solución profesional **TODO-EN-UNO** para reproducción automática y continua de videos en pantallas, con **tecnología anti-micro-cortes** y configuración ultra-optimizada. Ideal para puntos de venta, exhibiciones, ferias, señalización digital y aplicaciones de broadcast profesional.

Desarrollado por **Ignacio Manuel Centeno** (Desarrollador de Software), con el aval de **44 Contenidos**.

---

## 🎯 ¿Qué es VIDLOOP 2.0?

**VIDLOOP 2.0** es la evolución completa del sistema de videoloops, que integra en un **único script instalador** todas las funcionalidades, optimizaciones y correcciones desarrolladas:

- ✅ **Instalación completa automática** (Sistema + Software + Configuración)
- ✅ **Tecnología anti-micro-cortes** (Buffers 20x, GPU optimizada, CPU overclocking)
- ✅ **Force Display HDMI ultra-agresivo** (Solución a pantallas negras)
- ✅ **Configuración pi_video_looper optimizada** (video_looper.ini integrado)
- ✅ **Acceso remoto VPN** (ZeroTier automático)
- ✅ **Inicio automático con múltiples respaldos** (systemd + keepalive)
- ✅ **Diagnósticos integrados** (Script de troubleshooting incluido)
- ✅ **Modo optimización de imagen existente** (Para backups con pi_video_looper instalado)

---

## 🚀 Características principales

### 🎬 **Reproducción Ultra-Suave**
- **Anti-micro-cortes**: Buffers de audio/video 20x más grandes
- **GPU Memory**: 256MB asignados para aceleración de hardware
- **CPU Overclocking**: 1800MHz para máximo rendimiento
- **Transiciones**: Ultra-suaves de 0.05 segundos entre videos
- **Formatos optimizados**: MP4, H.264, MKV recomendados

### 📺 **Display Force Ultra-Agresivo**
- **HDMI Keepalive**: Servicio que mantiene la señal HDMI activa 24/7
- **Config.txt optimizado**: Parámetros HDMI forzados para máxima compatibilidad
- **Resolución fija**: 1920x1080 estable sin fluctuaciones
- **Boot display**: Fuerza la señal desde el arranque del sistema

### ⚙️ **Configuración Avanzada**
- **video_looper.ini**: Integrado con parámetros anti-micro-cortes
- **omxplayer optimizado**: Parámetros avanzados para reproducción fluida
- **Directorio personalizable**: Usa `/home/admin/VIDLOOP44` por defecto
- **Múltiples ubicaciones**: Configuración distribuida automáticamente

### 🔄 **Inicio Automático Robusto**
- **Servicio systemd**: Con prioridad máxima
- **HDMI keepalive**: Servicio independiente para mantener display
- **Reinicio automático**: Si el video falla, se reinicia automáticamente
- **Detección inteligente**: Funciona con instalaciones existentes

### 🌐 **Acceso Remoto Profesional**
- **ZeroTier VPN**: Acceso seguro desde cualquier lugar
- **SSH optimizado**: Con configuración de seguridad
- **Logs centralizados**: Diagnóstico remoto completo
- **Script de diagnóstico**: Troubleshooting automático incluido

---

## 📋 Requisitos del sistema

- **Raspberry Pi**: 3B+, 4B, o superior (recomendado: 4B con 4GB RAM)
- **Sistema operativo**: Raspberry Pi OS (32-bit o 64-bit)
- **Tarjeta SD**: Mínimo 16GB, recomendado 32GB+ (Clase 10)
- **Alimentación**: Fuente oficial de 5V/3A mínimo
- **Conectividad**: Puerto HDMI + Internet para instalación inicial

---

## 🔧 Instalación paso a paso

Ofrecemos una imagen con `VIDLOOP` ya instalado: PROXIMAMENTE.

## Kit de imagen maestra (nuevo)

Ahora el repo incluye un kit para construir una imagen `.img.xz` de VIDLOOP sobre Raspberry Pi OS con `pi_video_looper`:

- `image-kit/preclone-cleanup.sh`
- `image-kit/install-firstboot-service.sh`
- `image-kit/firstboot-init.sh`
- `image-kit/build-master-image.sh`
- `image-kit/systemd/vidloop-firstboot.service`

Guia completa en `image-kit/README.md`.

#### 1. **Copiar script a la Raspberry Pi**

# Clonar repositorio completo
git clone https://github.com/ignacentenox/VIDLOOP.git
cd VIDLOOP

#### 2. **Ejecutar optimización**

```bash
# Dar permisos de ejecución
chmod +x vidloop-definitivo.sh

# Ejecutar instalación completa (como sudo)
sudo ./vidloop-definitivo.sh
```

El script **detecta automáticamente** si hay una instalación existente y aplica solo las optimizaciones necesarias.

---

## 🎬 Proceso de instalación automático

El script realiza **automáticamente**:

### **Para instalación completa:**
- ✅ **Detección de usuario y sistema**
- ✅ **Actualización completa del sistema**
- ✅ **Instalación de todas las dependencias**
- ✅ **Clonado e instalación de pi_video_looper**
- ✅ **Configuración de GPU y CPU** (256MB GPU, 1800MHz CPU)
- ✅ **Optimización de config.txt**
- ✅ **Configuración anti-micro-cortes** (video_looper.ini optimizado)
- ✅ **Setup HDMI force ultra-agresivo**
- ✅ **Instalación y configuración de ZeroTier VPN**
- ✅ **Creación de servicios systemd** (inicio automático)
- ✅ **Scripts de diagnóstico y utilidades**
- ✅ **Configuración de SSH seguro**

### **Para optimización de imagen existente:**
- ✅ **Respeta instalación existente** de pi_video_looper
- ✅ **Aplica optimizaciones anti-micro-cortes**
- ✅ **Reinstala ZeroTier limpiamente**
- ✅ **Configura HDMI ultra-agresivo**
- ✅ **Optimiza sistema operativo**
- ✅ **Mantiene compatibilidad** con configuración original

---

## 🎬 Uso del sistema

### **Agregar videos**
1. **Crear/verificar directorio de videos:**
   ```bash
   /home/admin/videos
   ```

2. **Subir videos** (formatos recomendados):
   - ✅ **MP4** (H.264) - **RECOMENDADO**
   - ✅ **H.264** puro - **ÓPTIMO**
   - ✅ **MKV** - **BUENO**
   - ⚠️ AVI, WMV, FLV (pueden causar micro-cortes)

3. **Los videos se reproducen automáticamente** al arrancar la RPi

### **Comandos útiles**

#### **Para instalación completa:**
```bash
# Ver estado del servicio
sudo systemctl status video_looper

# Reiniciar reproducción
sudo systemctl restart video_looper

# Ver logs en tiempo real
sudo journalctl -u video_looper -f

# Ejecutar diagnóstico completo
sudo /usr/local/bin/vidloop-definitivo-diagnostic.sh
```

#### **Para imagen existente optimizada:**
```bash
# Usar instalación original
sudo systemctl restart video_looper

# Usar script optimizado (respaldo)
sudo /usr/local/bin/vidloop-definitivo.sh

# Ver logs optimizados
tail -f /var/log/vidloop-definitivo.log

# Diagnóstico completo
sudo /usr/local/bin/vidloop-definitivo-diagnostic.sh
```

---

## 🌐 Configuración VPN (ZeroTier)

### **Durante la instalación:**
El script pregunta si deseas configurar ZeroTier y solicita el Network ID.

### **Configuración manual posterior:**
```bash
# Unir a tu red ZeroTier
sudo zerotier-cli join TU_NETWORK_ID

# Ver redes conectadas
sudo zerotier-cli listnetworks

# Ver información del nodo
sudo zerotier-cli info
```

### **Autorizar en panel web:**
1. Ir a [ZeroTier Central](https://my.zerotier.com/)
2. Autorizar la nueva Raspberry Pi  
3. Anotar la IP asignada

### **Acceso SSH remoto:**

## 🔧 Configuración avanzada

### **Personalizar video_looper.ini**

#### **Para instalación completa:**
Archivo en: `/opt/video_looper/video_looper.ini`

#### **Para imagen existente:**
El script busca y optimiza **todos** los archivos `video_looper.ini` encontrados.

**Parámetros clave anti-micro-cortes:**
```ini
# Buffers aumentados 20x
omxplayer_extra_args = --audio_queue 20 --video_queue 20 --fps 30

# Transición ultra-suave
wait_time = 0.05

# Directorio optimizado
directory_path = /home/admin/VIDLOOP44

# Hardware acceleration
hw_accel = true
```

### **Modificar directorio de videos**
```bash
# Editar configuración principal
sudo nano /opt/video_looper/video_looper.ini

# Cambiar ruta:
directory_path = /tu/nueva/ruta

# Reiniciar servicio
sudo systemctl restart video_looper
```

---

## 🛠️ Troubleshooting

### **Script de diagnóstico automático**
```bash
# Ejecutar diagnóstico completo (detecta modo automáticamente)
sudo /usr/local/bin/vidloop-definitivo-diagnostic.sh
```

### **Problemas comunes y soluciones**

**❌ Pantalla negra al arrancar:**
```bash
# Forzar HDMI manualmente
sudo tvservice -p
sudo tvservice --explicit="CEA 16 HDMI"

# Verificar servicio HDMI keepalive
sudo systemctl status hdmi-keepalive
```

**❌ Videos con micro-cortes:**
```bash
# Verificar configuración anti-micro-cortes
grep -E "(audio_queue|video_queue)" /opt/video_looper/video_looper.ini

# Debe mostrar: audio_queue 20, video_queue 20
```

**❌ Servicio no inicia:**
```bash
# Para instalación completa
sudo journalctl -u video_looper -n 50

# Para imagen existente
sudo systemctl restart video_looper
tail -f /var/log/vidloop-definitivo.log
```

**❌ No encuentra videos:**
```bash
# Verificar directorio y permisos
ls -la /home/admin/VIDLOOP44/
sudo chown -R admin:admin /home/admin/VIDLOOP44/
```

**❌ Problemas con imagen existente:**
```bash
# Re-ejecutar optimización
sudo ./vidloop-definitivo.sh

# Verificar instalación existente detectada
sudo /usr/local/bin/vidloop-definitivo-diagnostic.sh
```

---

## 📊 Especificaciones técnicas

### **Optimizaciones de hardware**
- **GPU Memory**: 256MB (óptimo para video HD)
- **CPU Frequency**: 1800MHz (overclock estable)
- **GPU Frequency**: 500MHz (aceleración máxima)
- **Memory Split**: 256MB para GPU
- **I/O Scheduler**: Deadline (óptimo para video)

### **Configuración de software**
- **Video Player**: omxplayer (hardware-accelerated)
- **Audio Buffers**: 20x más grandes (anti-micro-cortes)
- **Video Buffers**: 20x más grandes (reproducción fluida)
- **Frame Rate**: 30fps fijo (estabilidad)
- **Priority**: Nice -20 (máxima prioridad CPU)

### **Servicios del sistema**

#### **Instalación completa:**
- `video_looper.service` - Reproductor principal
- `hdmi-keepalive.service` - Mantiene señal HDMI
- `zerotier-one.service` - VPN para acceso remoto

#### **Imagen existente optimizada:**
- Mantiene servicios originales
- Añade `hdmi-keepalive.service`
- Script optimizado como respaldo

---

## 📈 Ventajas VIDLOOP 2.0

| Característica | VIDLOOP v1.0 | VIDLOOP 2.0 |
|----------------|--------------|-------------|
| **Instalación** | Solo nueva | ✅ Nueva + Optimización de existente |
| **Detección automática** | Manual | ✅ Detecta instalaciones existentes |
| **Anti-micro-cortes** | Básico | ✅ Buffers 20x + parámetros avanzados |
| **Display Force** | Estándar | ✅ Ultra-agresivo + keepalive |
| **ZeroTier** | Configuración manual | ✅ Reinstalación limpia automática |
| **Compatibilidad** | Solo nueva instalación | ✅ Respeta configuraciones existentes |
| **Diagnósticos** | Básico | ✅ Detecta modo y adapta diagnóstico |
| **Flexibilidad** | Un solo modo | ✅ Dos modos: completo + optimización |

---

## 💡 Casos de uso recomendados

### **🏪 Retail y puntos de venta**
- Promociones y ofertas en loop
- Información de productos
- Señalización digital interstore

### **🎪 Ferias y eventos**
- Presentaciones corporativas
- Demos de productos
- Información institucional

### **📺 Broadcast y televisión**
- Separadores de programación
- Publicidades en loop
- Contenido de relleno

### **🏢 Oficinas corporativas**
- Comunicación interna
- KPIs y métricas en tiempo real
- Información para visitantes

### **🔧 Optimización de instalaciones existentes**
- Mejora de sistemas ya implementados
- Actualización sin reinstalación completa
- Mantenimiento de configuraciones personalizadas

---

## 🔄 Actualizaciones y mantenimiento

### **Actualizar VIDLOOP 2.0**
```bash
# Descargar nueva versión
curl -O https://raw.githubusercontent.com/ignacentenox/VIDLOOP/main/RASPBERRY-PAGE/vidloop-definitivo.sh
chmod +x vidloop-definitivo.sh

# Ejecutar (detecta automáticamente el modo)
sudo ./vidloop-definitivo.sh
```

### **Mantenimiento periódico**
```bash
# Limpiar logs (mensual)
sudo journalctl --vacuum-time=30d

# Verificar salud del sistema
sudo /usr/local/bin/vidloop-definitivo-diagnostic.sh

# Actualizar sistema base (trimestral)
sudo apt update && sudo apt upgrade -y

# Verificar temperatura (importante con overclock)
vcgencmd measure_temp
```

---

## 📁 Estructura del proyecto

```
VIDLOOP/
│   ├── vidloop-definitivo.sh      # Script principal VIDLOOP 2.0
│   ├── video_looper.ini           # Configuración optimizada
│   └── README.md                  # Este archivo
├── assets/
│   └── configuraciones/           # Archivos de configuración adicionales
└── docs/
    └── troubleshooting.md         # Guía de resolución de problemas
```

---

## 📞 Soporte técnico profesional

### **Desarrollado por:**
**Ignacio Manuel Centeno**  
🔧 Desarrollador de Software  
📧 [ignacenteno46@gmail.com](mailto:ignacenteno46@gmail.com)  
🌐 Especialista en Raspberry Pi y sistemas embebidos

### **Avalado por:**
**44 Contenidos**  
🎬 Soluciones audiovisuales y digitales profesionales  
📺 Especialistas en broadcast digital

### **Soporte incluido:**
- ✅ **Instalación remota** vía ZeroTier VPN
- ✅ **Configuración personalizada** según necesidades
- ✅ **Optimización de sistemas existentes**
- ✅ **Troubleshooting** y resolución de problemas
- ✅ **Actualizaciones** y mejoras continuas
- ✅ **Documentación técnica** completa
- ✅ **Soporte para migraciones** desde v1.0

---

## 🚀 ¿Listo para la nueva generación de videoloops?

**VIDLOOP 2.0** es la solución más completa y robusta del mercado para Raspberry Pi, diseñada para entornos profesionales que requieren:

- ⚡ **Máxima estabilidad** en cualquier escenario
- 🎯 **Cero micro-cortes** garantizado
- 🔧 **Fácil mantenimiento** y actualización
- 🌐 **Acceso remoto seguro**
- 💪 **Soporte técnico profesional**
- 🔄 **Compatibilidad** con sistemas existentes
- 📈 **Migración sin pérdida** de configuraciones

### **Novedades en VIDLOOP 2.0:**
- 🆕 **Modo optimización** para imágenes existentes
- 🆕 **Detección automática** de instalaciones
- 🆕 **ZeroTier reinstalación limpia**
- 🆕 **Diagnósticos adaptativos**
- 🆕 **Mayor compatibilidad** con diferentes configuraciones

### **¡Consultanos para implementaciones a medida!**

**¿Necesitas migrar sistemas existentes? ¿Múltiples pantallas? ¿Configuración corporativa? ¿Integración con sistemas existentes?**

Contactanos para soluciones y descuentos por volumen.

---

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo `LICENSE` para más detalles.

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

## ⭐ Agradecimientos

- **Adafruit** por pi_video_looper
- **Raspberry Pi Foundation** por el ecosistema RPi
- **ZeroTier** por la solución VPN
- **Comunidad Open Source** por las herramientas utilizadas

---

*VIDLOOP 2.0 - La evolución inteligente de los sistemas de videoloops para Raspberry Pi* 🎯  
*Compatible con instalaciones existentes • Optimización automática • Soporte profesional*

[![GitHub stars](https://img.shields.io/github/stars/ignacentenox/VIDLOOP.svg)](https://github.com/ignacentenox/VIDLOOP/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/ignacentenox/VIDLOOP.svg)](https://github.com/ignacentenox/VIDLOOP/network)
[![GitHub issues](https://img.shields.io/github/issues/ignacentenox/VIDLOOP.svg)](https://github.com/ignacentenox/VIDLOOP/issues)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
