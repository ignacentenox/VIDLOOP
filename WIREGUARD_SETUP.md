# 🔐 WireGuard: Guía Completa para Agregar Nuevos Clientes

## 📋 Resumen

WireGuard está **100% funcional** en el script VIDLOOP V3.0. Aquí te explico cómo crear y agregar nuevos clients (RPis) desde tu VPS.

---

## 🎯 Arquitectura Básica

```
VPS (Servidor WireGuard)
├── Interfaz: wg0
├── IP: 10.8.0.1/24
└── Puerto: 51820/UDP

Clientes (RPis)
├── TOTEM LANSER 1: 10.8.0.2
├── TOTEM LANSER 2: 10.8.0.3
└── Nuevos: 10.8.0.X (asignar secuencial)
```

---

## 🔑 PASO 1: Preparar el VPS (Linux)

### 1.1 Instalar WireGuard en el servidor

```bash
# Debian/Ubuntu
sudo apt-get update
sudo apt-get install -y wireguard wireguard-tools resolvconf
```

### 1.2 Generar claves del servidor

```bash
# Crear directorio seguro
sudo mkdir -p /etc/wireguard
cd /etc/wireguard

# Generar par de claves del servidor
sudo wg genkey | sudo tee server_private.key | sudo wg pubkey | sudo tee server_public.key

# Asegurar permisos
sudo chmod 600 server_private.key
```

### 1.3 Crear config del servidor (`wg0.conf`)

```bash
sudo nano /etc/wireguard/wg0.conf
```

**Contenido:**

```ini
[Interface]
# Dirección IP del servidor en la red VPN
Address = 10.8.0.1/24
ListenPort = 51820

# Lee la clave privada desde archivo
PrivateKey = <CONTENIDO_DE_server_private.key>

# Firewall: Forward traffic y NAT outbound
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
```

### 1.4 Activar WireGuard en servidor

```bash
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
sudo systemctl status wg-quick@wg0
sudo wg show
```

---

## 👥 PASO 2: Crear Clientes (RPi)

### 2.1 Generar claves para CADA cliente

Ejecuta en el **servidor**:

```bash
# Para cliente 1 (ej: TOTEM LANSER 3 con IP 10.8.0.4)
wg genkey | tee client3_private.key | wg pubkey > client3_public.key
```

### 2.2 Crear entrada del cliente en servidor

```bash
sudo nano /etc/wireguard/wg0.conf
```

**Agregar al final:**

```ini
[Peer]
# Client: TOTEM LANSER 3
PublicKey = <CONTENIDO_DE_client3_public.key>
AllowedIPs = 10.8.0.4/32
```

### 2.3 Recargar config en servidor

```bash
sudo systemctl reload wg-quick@wg0
sudo wg show
```

---

## 📱 PASO 3: Instalar Cliente en RPi

```bash
export VIDLOOP_WG_PRIVATE_KEY="<CONTENIDO_DE_client3_private.key>"
export VIDLOOP_WG_SERVER_PUBLIC_KEY="<CONTENIDO_DE_server_public.key>"
export VIDLOOP_WG_CLIENT_ADDRESS="10.8.0.4/24"
export VIDLOOP_WG_SERVER_ENDPOINT="tu-vps-ip.com:51820"
export ENABLE_WIREGUARD="true"

sudo bash VIDLOOP-V3.0.sh
```

---

## 🧪 PASO 4: Validar Conectividad

```bash
# Desde el cliente (RPi)
sudo wg show
ip addr show wg0
ping 10.8.0.1

# Desde el servidor
sudo wg show
ping 10.8.0.4
```

---

## 📌 Notas Importantes

1. Nunca compartas claves privadas por texto plano
2. Puerto 51820/UDP debe estar abierto en el firewall del servidor
3. Usa `systemctl reload` para cambios sin perder conexiones activas

Ver documentación completa en README_ACTUALIZADO_V1.1.md
