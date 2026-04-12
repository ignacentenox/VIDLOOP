# VIDLOOP - Guia Tecnica Interna

Esta guia documenta el uso operativo de scripts auxiliares de WireGuard usados en el entorno VIDLOOP para provisionar Raspberry Pi, registrar peers en el VPS y migrar la operacion a IPs VPN.

No forma parte del README principal porque el repo publico debe mantener foco en el instalador base.

## Alcance

Importante:

- el instalador base de este repo soporta WireGuard por variables de entorno
- los scripts auxiliares documentados aca son herramientas operativas complementarias
- esos scripts pueden vivir en un repo de dashboard, en un repo de ops o distribuirse aparte segun tu despliegue

Scripts documentados:

```bash
wireguard_setup_rpi.sh
wireguard_add_peer_vps.sh
wireguard_generate_client_conf.sh
switch_devices_to_vpn.py
```

## Topologia asumida

- VPS WireGuard: `10.8.0.1`
- Red VPN: `10.8.0.0/24`
- Endpoint publico del servidor: `82.25.77.55:51820`
- Interfaz del servidor: `wg0`

## Flujo recomendado

### Opcion A: configurar la Raspberry automaticamente

Usar esta opcion cuando tenes acceso shell a la Raspberry y queres que el equipo genere su propia configuracion.

Paso 1. En la Raspberry, ejecutar como root:

```bash
sudo bash wireguard_setup_rpi.sh 10.8.0.2/24
```

Esto normalmente:

- instala WireGuard si hace falta
- genera `/etc/wireguard/private.key`
- genera `/etc/wireguard/public.key`
- crea `/etc/wireguard/wg0.conf`
- habilita `wg-quick@wg0`
- muestra la public key del cliente

Paso 2. Copiar la public key mostrada.

Paso 3. En el VPS, agregar el peer:

```bash
sudo bash wireguard_add_peer_vps.sh 10.8.0.2 PUBLIC_KEY_DE_LA_RPI nombre-rpi
```

Paso 4. Verificar:

```bash
sudo wg show
ping -c 3 10.8.0.1
```

### Opcion B: generar configuracion manual del cliente

Usar esta opcion cuando queres construir el `wg0.conf` fuera del cliente.

Paso 1. Generar claves:

```bash
wg genkey | tee client.private | wg pubkey > client.public
```

Paso 2. Generar el `wg0.conf` del cliente:

```bash
sudo bash wireguard_generate_client_conf.sh 10.8.0.3/24 "$(cat client.private)" /root/rpi-3-wg0.conf
```

Paso 3. Copiar el archivo al cliente como `/etc/wireguard/wg0.conf`.

Paso 4. Levantar la interfaz:

```bash
sudo systemctl enable --now wg-quick@wg0
```

Paso 5. Registrar el peer en el VPS:

```bash
sudo bash wireguard_add_peer_vps.sh 10.8.0.3 "$(cat client.public)" rpi-3
```

## Detalle por script

### `wireguard_setup_rpi.sh`

Uso:

```bash
sudo bash wireguard_setup_rpi.sh [vpn_cidr] [server_public_key] [server_endpoint] [allowed_ips] [dns]
```

Defaults esperados:

- `vpn_cidr`: `10.8.0.2/24`
- `server_endpoint`: `82.25.77.55:51820`
- `allowed_ips`: `10.8.0.0/24`
- `dns`: `1.1.1.1`

### `wireguard_add_peer_vps.sh`

Uso:

```bash
sudo bash wireguard_add_peer_vps.sh <ip_vpn> <public_key> [nombre_peer]
```

Notas:

- corre en el VPS
- agrega el peer a `/etc/wireguard/wg0.conf`
- la IP se pasa sin mascara, por ejemplo `10.8.0.2`

### `wireguard_generate_client_conf.sh`

Uso:

```bash
sudo bash wireguard_generate_client_conf.sh <ip_vpn_cidr> <client_private_key> <output_path> [allowed_ips] [dns]
```

Notas:

- no genera claves
- consume la private key del cliente
- suele leer la public key del servidor desde `/etc/wireguard/server_public.key`
- deja el archivo final con permisos restringidos

### `switch_devices_to_vpn.py`

Uso:

```bash
python switch_devices_to_vpn.py --db data/vidloop_dash.db --mapping-file devices_vpn.example.json --dry-run
python switch_devices_to_vpn.py --db data/vidloop_dash.db --mapping-file devices_vpn.example.json
```

Sirve para migrar los dispositivos del dashboard a sus IPs VPN una vez que la red privada ya responde correctamente.

## Relacion con VIDLOOP V3

Si ya tenes el `wg0.conf` del cliente, el instalador de este repo puede aplicarlo directamente con:

```bash
WG_B64="$(base64 -w0 wg0.conf 2>/dev/null || base64 < wg0.conf | tr -d '\n')"
sudo ENABLE_WIREGUARD=true VIDLOOP_WG_CONFIG_B64="$WG_B64" ./VIDLOOP-V3.0.sh
```

Eso cubre la instalacion del lado Raspberry. El alta del peer en el servidor y la operacion posterior siguen siendo responsabilidad del entorno de infraestructura.

## Riesgos y observaciones

- Si cambian red, endpoint o claves del servidor, hay que ajustar los scripts auxiliares.
- Esta guia no reemplaza una politica de secretos; no conviene versionar claves privadas.
- Aunque este archivo no esta enlazado desde el README principal, sigue siendo visible para cualquiera con acceso al repositorio.