# Configuración WireGuard + TOTEM LANSER 2

**Objetivo:** Conectar TOTEM LANSER 2 (192.168.0.53) a VPS (82.25.77.55) vía WireGuard para acceso remoto al dashboard y upload de videos.

---

## 📋 Requisitos previos

- ✅ VPS con WireGuard instalado (82.25.77.55)
- ✅ RPi TOTEM LANSER 2 con VIDLOOP instalado
- ✅ Acceso SSH a ambas máquinas

---

## 🔧 Paso 1: Verificar WireGuard en VPS

```bash
ssh root@82.25.77.55
# Password: Vidloop@44tech

# Verificar instalación
wg --version
ip link show wg0  # Debería existir la interfaz

# Ver configuración actual
wg show
```

Si WireGuard NO está instalado, instalarlo:
```bash
apt-get update
apt-get install -y wireguard wireguard-tools
```

---

## 🔑 Paso 2: Generar claves para TOTEM

**En la VPS:**

```bash
cd /tmp
wg genkey | tee totem_private.key | wg pubkey > totem_public.key

# Verificar
cat totem_private.key
cat totem_public.key
```

---

## 👥 Paso 3: Agregar TOTEM como peer en VPS

**En la VPS:**

```bash
# Ver configuración actual (necesitarás la clave pública del servidor)
wg show wg0

# Obtener la IP que usará TOTEM en la red privada
# (ej: 10.0.0.2 si la red es 10.0.0.0/24)

# Agregar el peer
wg set wg0 peer $(cat totem_public.key) allowed-ips 10.0.0.2/32

# Verificar que se agregó
wg show wg0
```

---

## 📄 Paso 4: Crear wg0.conf para TOTEM

**En la VPS, crear el archivo config:**

```bash
cat > /tmp/wg0.conf << 'WGEOF'
[Interface]
PrivateKey = $(cat /tmp/totem_private.key)
Address = 10.0.0.2/24
DNS = 8.8.8.8, 8.8.4.4
ListenPort = 51820

[Peer]
PublicKey = $(wg pubkey < /tmp/vps_private.key)
Endpoint = 82.25.77.55:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
WGEOF
```

**⚠️ Reemplazar valores reales:**
- `PrivateKey`: Contenido de `/tmp/totem_private.key`
- `PublicKey`: Clave pública del servidor VPS (obtener con `wg pubkey < /ruta/vps_private.key`)
- `Endpoint`: 82.25.77.55:51820 (verificar puerto en VPS: `wg show`)
- `AllowedIPs`: 10.0.0.0/24 (rango privado de la VPN)

Resultado final esperado:
```ini
[Interface]
PrivateKey = eHt8Jk2L9pQvR4mN5xw6yZ1aB2cD3eF4gH5iJ6kL7mN=
Address = 10.0.0.2/24
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = M9nO8pQ7rS6tU5vW4xX3yY2zA1bB0cC9dD8eE7fF6gG=
Endpoint = 82.25.77.55:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
```

---

## 📤 Paso 5: Transferir wg0.conf a TOTEM

**Desde la VPS:**

```bash
scp /tmp/wg0.conf vidloop@192.168.0.53:~/wg0.conf
# Password: 4455
```

---

## 🚀 Paso 6: Aplicar configuración en TOTEM

**En TOTEM (SSH o local):**

```bash
cd ~/VIDLOOP-main

# Actualizar si es necesario
git pull 2>/dev/null || (
    cd ~
    curl -fL https://github.com/ignacentenox/VIDLOOP/archive/refs/heads/main.zip -o VIDLOOP-new.zip
    unzip -q VIDLOOP-new.zip
    cp VIDLOOP-main/reconfigure-wireguard.sh ~/VIDLOOP-main/
)

# Aplicar configuración
chmod +x reconfigure-wireguard.sh
./reconfigure-wireguard.sh ~/wg0.conf
```

---

## ✅ Paso 7: Verificar conectividad

**En TOTEM:**

```bash
# Ver interfaz
ip link show wg0
ip addr show wg0

# Ver estado
wg show wg0

# Probar ping
ping -c 3 10.0.0.1  # Gateway VPS

# Probar acceso a VPS
ssh root@10.0.0.1   # Desde red privada
```

---

## 🎯 Paso 8: Acceso remoto al dashboard

Una vez WireGuard funciona:

**Desde tu máquina local:**
```bash
# Conectarse a VPN (si tienes cliente WireGuard)
# Luego acceder: http://10.0.0.2:8080 (o puerto configurado)
```

**O si usas bastion SSH:**
```bash
ssh -L 8080:10.0.0.2:8080 root@82.25.77.55
# Luego: http://localhost:8080
```

---

## 🔍 Troubleshooting

### WireGuard no inicia
```bash
sudo systemctl status wg-quick@wg0
sudo wg-quick down wg0
sudo wg-quick up wg0
```

### Sin conectividad a VPS
```bash
# Ver rutas
ip route
netstat -rn

# Ver peers conectados
wg show

# Traceroute
traceroute 10.0.0.1
```

### video_looper se pausó
```bash
sudo systemctl restart video_looper
sudo systemctl status video_looper
```

---

## 📝 Notas

- **Puerto WireGuard por defecto:** 51820 (UDP)
- **Rango de red privada:** 10.0.0.0/24 (personalizable)
- **IP TOTEM en VPN:** 10.0.0.2 (configurar según disponibilidad)
- **Persistent Keepalive:** 25 segundos (necesario para NAT)
- **DNS:** 8.8.8.8 (o configurar DNS privado del servidor)

---

## 🔐 Seguridad

- ✅ Cambiar password SSH en VPS (NO usar "Vidloop@44tech" en producción)
- ✅ Restringir SSH solo a ips autorizadas
- ✅ Usar firewall en VPS (iptables/ufw)
- ✅ Rotar claves WireGuard periódicamente
- ✅ Verificar logs: `journalctl -u wg-quick@wg0 -f`
