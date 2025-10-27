# VIDLOOP DEFINITIVO - Sistema de Videoloops para Raspberry Pi

Solución profesional **TODO-EN-UNO** para reproducción automática y continua de videos en pantallas, con **tecnología anti-micro-cortes** y configuración ultra-optimizada. Ideal para puntos de venta, exhibiciones, ferias, señalización digital y aplicaciones de broadcast profesional.

Desarrollado por **Ignacio Manuel Centeno** (Desarrollador de Software), con el aval de **44 Contenidos**.

---

## 🎯 ¿Qué es VIDLOOP DEFINITIVO?

**VIDLOOP DEFINITIVO** es la evolución completa del sistema de videoloops, que integra en un **único script instalador** todas las funcionalidades, optimizaciones y correcciones desarrolladas:

- ✅ **Instalación completa automática** (Sistema + Software + Configuración)
- ✅ **Tecnología anti-micro-cortes** (Buffers 20x, GPU optimizada, CPU overclocking)
- ✅ **Force Display HDMI ultra-agresivo** (Solución definitiva a pantallas negras)
- ✅ **Configuración pi_video_looper optimizada** (video_looper.ini integrado)
- ✅ **Acceso remoto VPN** (ZeroTier automático)
- ✅ **Inicio automático con múltiples respaldos** (systemd + rc.local + keepalive)
- ✅ **Diagnósticos integrados** (Script de troubleshooting incluido)

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
- **Servicio systemd**: `vidloop-definitivo.service` con prioridad máxima
- **Respaldo rc.local**: Por si systemd falla
- **HDMI keepalive**: Servicio independiente para mantener display
- **Reinicio automático**: Si el video falla, se reinicia en 3 segundos

### 🌐 **Acceso Remoto Profesional**
- **ZeroTier VPN**: Acceso seguro desde cualquier lugar
- **SSH optimizado**: Puerto 44 con configuración de seguridad
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

### 1. **Preparar la Raspberry Pi**
```bash
# Actualizar sistema base (opcional, el script lo hace automáticamente)
sudo apt update && sudo apt upgrade -y
```

### 2. **Descargar VIDLOOP DEFINITIVO**
```bash
# Opción A: Clonar repositorio completo
git clone https://github.com/ignacentenox/VIDLOOP.git
cd VIDLOOP

# Opción B: Descargar solo el script
curl -O https://raw.githubusercontent.com/ignacentenox/VIDLOOP/main/RASPBERRY-PAGE/vidloop-definitivo.sh
```

### 3. **Ejecutar instalación definitiva**
```bash
# Dar permisos de ejecución
chmod +x vidloop-definitivo.sh

# Ejecutar instalación completa (como sudo)
sudo ./vidloop-definitivo.sh
```

### 4. **Proceso automático**
El script realiza **automáticamente**:

- ✅ **Detección de usuario y sistema**
- ✅ **Actualización completa del sistema**
- ✅ **Instalación de todas las dependencias**
- ✅ **Configuración de GPU y CPU** (256MB GPU, 1800MHz CPU)
- ✅ **Optimización de config.txt y cmdline.txt**
- ✅ **Instalación de pi_video_looper** (desde GitHub)
- ✅ **Configuración anti-micro-cortes** (video_looper.ini optimizado)
- ✅ **Setup HDMI force ultra-agresivo**
- ✅ **Instalación y configuración de ZeroTier VPN**
- ✅ **Creación de servicios systemd** (inicio automático)
- ✅ **Scripts de diagnóstico y utilidades**
- ✅ **Configuración de SSH seguro** (puerto 22)

### 5. **Reinicio automático**
```bash
# El script reinicia automáticamente al finalizar
# Si no reinicia automáticamente:
sudo reboot
```

---

## 🎬 Uso del sistema

### **Agregar videos**
1. **Crear/verificar directorio de videos:**
   ```bash
   mkdir -p /home/admin/VIDLOOP44
   ```

2. **Subir videos** (formatos recomendados):
   - ✅ **MP4** (H.264) - **RECOMENDADO**
   - ✅ **H.264** puro - **ÓPTIMO**
   - ✅ **MKV** - **BUENO**
   - ⚠️ AVI, WMV, FLV (pueden causar micro-cortes)

3. **Los videos se reproducen automáticamente** al arrancar la RPi

### **Comandos útiles**
```bash
# Ver estado del servicio
sudo systemctl status vidloop-definitivo.service

# Reiniciar reproducción
sudo systemctl restart vidloop-definitivo.service

# Ver logs en tiempo real
sudo journalctl -u vidloop-definitivo.service -f

# Ejecutar diagnóstico completo
sudo /usr/local/bin/vidloop-definitivo-diagnostic.sh

# Verificar configuración
cat /opt/video_looper/video_looper.ini
```

---

## 🌐 Configuración VPN (ZeroTier)

### **Configurar acceso remoto:**
1. **El script instala ZeroTier automáticamente**

2. **Unir a tu red ZeroTier:**
   ```bash
   sudo zerotier-cli join TU_NETWORK_ID
   ```

3. **Autorizar en el panel web:**
   - Ir a [ZeroTier Central](https://my.zerotier.com/)
   - Autorizar la nueva Raspberry Pi
   - Anotar la IP asignada

4. **Acceso SSH remoto:**
   ```bash
   ssh admin@IP_ZEROTIER -p 44
   ```

---

## 🔧 Configuración avanzada

### **Personalizar video_looper.ini**
El archivo se encuentra en: `/opt/video_looper/video_looper.ini`

**Parámetros clave anti-micro-cortes:**
```ini
# Buffers aumentados 20x
omxplayer_extra_args = --audio_queue 20 --video_queue 20

# Transición ultra-suave
wait_time = 0.05

# GPU optimizada
gpu_mem = 256

# Resolución fija
width = 1920
height = 1080
```

### **Modificar directorio de videos**
```bash
# Editar configuración
sudo nano /opt/video_looper/video_looper.ini

# Cambiar ruta:
directory_path = /tu/nueva/ruta

# Reiniciar servicio
sudo systemctl restart vidloop-definitivo.service
```

---

## 🛠️ Troubleshooting

### **Script de diagnóstico automático**
```bash
# Ejecutar diagnóstico completo
sudo /usr/local/bin/vidloop-definitivo-diagnostic.sh
```

### **Problemas comunes y soluciones**

**❌ Pantalla negra al arrancar:**
```bash
# Forzar HDMI manualmente
sudo tvservice -p
sudo tvservice --explicit="CEA 16 HDMI"
```

**❌ Videos con micro-cortes:**
```bash
# Verificar configuración anti-micro-cortes
grep -E "(audio_queue|video_queue)" /opt/video_looper/video_looper.ini

# Debe mostrar: audio_queue 20, video_queue 20
```

**❌ Servicio no inicia:**
```bash
# Ver logs de error
sudo journalctl -u vidloop-definitivo.service -n 50

# Reiniciar servicio
sudo systemctl restart vidloop-definitivo.service
```

**❌ No encuentra videos:**
```bash
# Verificar directorio y permisos
ls -la /home/admin/VIDLOOP44/
sudo chown -R admin:admin /home/admin/VIDLOOP44/
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
- **Frame Rate**: 25fps fijo (estabilidad)
- **Priority**: Nice -20 (máxima prioridad CPU)

### **Servicios del sistema**
- `vidloop-definitivo.service` - Reproductor principal
- `hdmi-keepalive.service` - Mantiene señal HDMI
- `zerotier-one.service` - VPN para acceso remoto

---

## 📈 Ventajas vs versión anterior

| Característica | Versión Anterior | VIDLOOP DEFINITIVO |
|----------------|------------------|-------------------|
| **Instalación** | Manual paso a paso | ✅ Automática completa |
| **Anti-micro-cortes** | No incluido | ✅ Buffers 20x optimizados |
| **Display Force** | Básico | ✅ Ultra-agresivo + keepalive |
| **Configuración** | Manual | ✅ video_looper.ini integrado |
| **Inicio automático** | Solo systemd | ✅ Triple respaldo |
| **Diagnósticos** | Manual | ✅ Script automático incluido |
| **Actualización** | Reinstalación completa | ✅ Script único actualizable |

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

---

## 🔄 Actualizaciones y mantenimiento

### **Actualizar el sistema**
```bash
# Actualizar VIDLOOP DEFINITIVO
curl -O https://raw.githubusercontent.com/ignacentenox/VIDLOOP/vidloop-definitivo.sh
chmod +x vidloop-definitivo.sh
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
📺 Especialistas en broadcast

### **Soporte incluido:**
- ✅ **Instalación remota** vía ZeroTier VPN
- ✅ **Configuración personalizada** según necesidades
- ✅ **Troubleshooting** y resolución de problemas
- ✅ **Actualizaciones** y mejoras continuas
- ✅ **Documentación técnica** completa

---

## 🚀 ¿Listo para profesionalizar tu comunicación visual?

**VIDLOOP DEFINITIVO** es la solución más completa y robusta del mercado para Raspberry Pi, diseñada para entornos profesionales que requieren:

- ⚡ **Máxima estabilidad**
- 🎯 **Cero micro-cortes**
- 🔧 **Fácil mantenimiento**
- 🌐 **Acceso remoto seguro**
- 💪 **Soporte técnico profesional**

### **¡Consultanos para implementaciones a medida!**

**¿Necesitas múltiples pantallas? ¿Configuración corporativa? ¿Integración con sistemas existentes?**

Contactanos para soluciones enterprise y descuentos por volumen. 

---

*VIDLOOP v1.0 - La evolución definitiva de los sistemas de videoloops para Raspberry Pi* 🎯
