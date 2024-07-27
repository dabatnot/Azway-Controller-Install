#!/bin/bash

# Attendre que checkInstall.sh se termine
echo "Attente de la fin de checkInstall[start](sync).ash..."

echo "Attente de la fin de checkInstall.ash..."
while ps aux | grep -v grep | grep "checkInstall.ash" > /dev/null; do
  sleep 1
done
echo "checkInstall.ash exited"

echo "Attente de la fin de checkInstall[start](sync).ash..."
while ps aux | grep -v grep | grep "checkInstall\[start\](sync).ash" > /dev/null; do
  sleep 1
done
echo "checkInstall\[start\](sync).ash exited"

#Remove Install dir
#rm -rf /recalbox/share/addons/azway/controller/install
echo "Removed install dir"

#Update existing checkInstall.sh script
rm /recalbox/share/userscripts/checkInstall\[start\]\(sync\).ash
mv /recalbox/share/addons/azway/controller/scripts/checkInstall.ash /recalbox/share/userscripts/checkInstall\[start\]\(sync\).ash

echo "Mise à jour terminée."

# Launch controller.py
echo "Running controller script"
python3 "/recalbox/share/addons/azway/controller/scripts/controller.py" &

exit 0
