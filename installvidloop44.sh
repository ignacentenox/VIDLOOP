#!/bin/bash

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

echo "Instalación completada. Reinicia la Raspberry Pi para aplicar los cambios."
