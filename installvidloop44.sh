echo "Desarrollado por IGNACE - Powered By: 44 Contenidos"

echo "Actualizando sistema..."
sudo apt-get update && sudo apt-get upgrade -y

echo "Instalando dependencias..."
sudo apt-get install -y git python3 python3-pip ffmpeg

echo "Configurando salida HDMI..."
sudo sed -i '/^#*hdmi_force_hotplug/s/^#//' /boot/config.txt
sudo sed -i '/^hdmi_force_hotplug/!a hdmi_force_hotplug=1' /boot/config.txt
sudo sed -i '/^#*hdmi_drive/s/^#//' /boot/config.txt
sudo sed -i '/^hdmi_drive/!a hdmi_drive=2' /boot/config.txt
sudo sed -i '/^#*config_hdmi_boost/s/^#//' /boot/config.txt
sudo sed -i '/^config_hdmi_boost/!a config_hdmi_boost=7' /boot/config.txt

echo "Dando permisos de ejecución a scripts..."
chmod +x *.sh

# (Opcional) Agregar tu script principal al inicio del sistema
# sudo cp tu_script.sh /usr/local/bin/
# sudo sed -i '$i /usr/local/bin/tu_script.sh &' /etc/rc.local

echo "Clonando e instalando pi_video_looper de Adafruit..."
git clone https://github.com/adafruit/pi_video_looper.git
cd pi_video_looper
sudo ./install.sh
cd ..

echo "Configurando video_looper.ini personalizado..."
cp ./video_looper.ini ./pi_video_looper/assets/video_looper.ini

echo "Instalando ZeroTier para VPN..."
curl -s https://install.zerotier.com | sudo bash

# === VIDLOOP-SETUP: Forzar HDMI + SSH con password (admin:4455) ===

# 1) Crear usuario admin si no existe y setear password 4455
if id -u admin >/dev/null 2>&1; then
  echo "[1/8] Usuario 'admin' existe. Actualizando contraseña..."
else
  echo "[1/8] Usuario 'admin' no existe. Creando usuario..."
  sudo adduser --disabled-password --gecos "" admin
fi
echo "admin:4455" | sudo chpasswd
echo "  -> contraseña seteada."

# 2) FORZAR SALIDA HDMI en /boot/config.txt (ya configurado antes, pero agregamos group/mode)
sudo sed -i '/^hdmi_force_hotplug=/d' /boot/config.txt 2>/dev/null || true
sudo sed -i '/^hdmi_drive=/d' /boot/config.txt 2>/dev/null || true
sudo sed -i '/^hdmi_group=/d' /boot/config.txt 2>/dev/null || true
sudo sed -i '/^hdmi_mode=/d' /boot/config.txt 2>/dev/null || true

sudo bash -c 'cat >> /boot/config.txt <<EOF

# ---- VIDLOOP HDMI ALWAYS ON ----
hdmi_force_hotplug=1
hdmi_drive=2
hdmi_group=1
hdmi_mode=16
EOF'

# 3) Evitar screen blanking
AUTOSTART="/etc/xdg/lxsession/LXDE-pi/autostart"
if [ -f "$AUTOSTART" ]; then
  sudo sed -i '/xset s off/d' "$AUTOSTART" || true
  sudo sed -i '/xset -dpms/d' "$AUTOSTART" || true
  sudo sed -i '/xset s noblank/d' "$AUTOSTART" || true
  sudo bash -c "cat >> $AUTOSTART <<EOF
@xset s off
@xset -dpms
@xset s noblank
EOF"
fi

# 4) SSH password only
SSHD="/etc/ssh/sshd_config"
sudo cp "$SSHD" "${SSHD}.bak.$(date +%s)" || true
sudo sed -i 's/^\s*PasswordAuthentication\s\+.*/PasswordAuthentication yes/' "$SSHD" || true
sudo sed -i 's/^\s*#\s*PasswordAuthentication\s\+.*/PasswordAuthentication yes/' "$SSHD" || true
sudo sed -i 's/^\s*PubkeyAuthentication\s\+.*/PubkeyAuthentication no/' "$SSHD" || true
grep -q "^PasswordAuthentication" "$SSHD" || sudo bash -c 'echo "PasswordAuthentication yes" >> '"$SSHD"
grep -q "^PubkeyAuthentication" "$SSHD" || sudo bash -c 'echo "PubkeyAuthentication no" >> '"$SSHD"
sudo systemctl restart ssh

# 5) tvservice ensure
if ! command -v tvservice >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y libraspberrypi-bin || true
fi

# 6) hdmi-keepalive script
sudo bash -c 'cat > /usr/local/bin/hdmi-keepalive.sh <<EOF
#!/bin/bash
while true; do
  if tvservice -s 2>/dev/null | grep -q "TV is off"; then
    tvservice -p
    chvt 6 && chvt 7
  else
    if ! tvservice -s 2>/dev/null | grep -q "0x12000"; then
      tvservice -p
      chvt 6 && chvt 7
    fi
  fi
  sleep 5
done
EOF'
sudo chmod +x /usr/local/bin/hdmi-keepalive.sh

# 7) systemd service
sudo bash -c 'cat > /etc/systemd/system/hdmi-keepalive.service <<EOF
[Unit]
Description=VIDLOOP HDMI keepalive
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hdmi-keepalive.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'
sudo systemctl daemon-reload
sudo systemctl enable --now hdmi-keepalive.service

echo
echo "=== FIN ==="
echo "Usuario: admin  |  Contraseña: 4455"
echo "SSH password only habilitado"
echo "HDMI forzado y servicio keepalive activo"
echo
echo "Reiniciando en 6s..."
sleep 6
sudo reboot
echo "Desarrollado por IGNACE - Powered By: 44 Contenidos"