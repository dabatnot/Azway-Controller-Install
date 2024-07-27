#!/bin/bash

# Attendre que checkInstall.sh se termine
echo "Attente de la fin de checkInstall.sh..."
while pgrep -x "checkInstall.sh" > /dev/null; do
  sleep 1
done

#Remove Install dir
#rm -rf /recalbox/share/addons/azway/controller/install
echo "Removed install dir"

#Update existing checkInstall.sh script
rm /recalbox/share/userscripts/checkInstall\[start\]\(sync\).sh
mv /recalbox/share/addons/azway/controller/scripts/checkInstall.sh /recalbox/share/userscripts/checkInstall\[start\]\(sync\).sh

echo "Mise à jour terminée."
exit 0
