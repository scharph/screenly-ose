#!/bin/bash -e

WEB_UPGRADE=false
BRANCH_VERSION=
MANAGE_NETWORK=
UPGRADE_SYSTEM=


echo -e "Screenly OSE requires a dedicated Raspberry Pi / SD card.\nYou will not be able to use the regular desktop environment once installed.\n"
read -p "Do you still want to continue? (y/N)" -n 1 -r -s INSTALL
if [ "$INSTALL" != 'y' ]; then
  echo
  exit 1
fi

BRANCH="wimmer-dirnberger"
    
EXTRA_ARGS="--skip-tags enable-ssl"

if grep -qF "Raspberry Pi 3" /proc/device-tree/model; then
  export DEVICE_TYPE="pi3"
elif grep -qF "Raspberry Pi 2" /proc/device-tree/model; then
  export DEVICE_TYPE="pi2"
else
  export DEVICE_TYPE="pi1"
fi

REPOSITORY=https://github.com/scharph/screenly-ose.git

sudo mkdir -p /etc/ansible
echo -e "[local]\nlocalhost ansible_connection=local" | sudo tee /etc/ansible/hosts > /dev/null

if [ ! -f /etc/locale.gen ]; then
  # No locales found. Creating locales with default UK/US setup.
  echo -e "en_GB.UTF-8 UTF-8\nen_US.UTF-8 UTF-8" | sudo tee /etc/locale.gen > /dev/null
  sudo locale-gen
fi

sudo sed -i 's/apt.screenlyapp.com/archive.raspbian.org/g' /etc/apt/sources.list
sudo apt update -y
sudo apt-get purge -y python-setuptools python-pip python-pyasn1
sudo apt-get install -y python-dev git-core libffi-dev libssl-dev
curl -s https://bootstrap.pypa.io/get-pip.py | sudo python


export MANAGE_NETWORK=false
sudo pip install ansible==2.8.2

sudo -u pi ansible localhost -m git -a "repo=$REPOSITORY dest=/home/pi/screenly version=$BRANCH"
cd /home/pi/screenly/ansible

sudo -E ansible-playbook site.yml $EXTRA_ARGS

sudo apt-get autoclean
sudo apt-get clean
sudo find /usr/share/doc -depth -type f ! -name copyright -delete
sudo find /usr/share/doc -empty -delete
sudo rm -rf /usr/share/man /usr/share/groff /usr/share/info /usr/share/lintian /usr/share/linda /var/cache/man
sudo find /usr/share/locale -type f ! -name 'en' ! -name 'de*' ! -name 'es*' ! -name 'ja*' ! -name 'fr*' ! -name 'zh*' -delete
sudo find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'de*' ! -name 'es*' ! -name 'ja*' ! -name 'fr*' ! -name 'zh*' -exec rm -r {} \;

cd /home/pi/screenly && git rev-parse HEAD > /home/pi/.screenly/latest_screenly_sha
sudo chown -R pi:pi /home/pi

echo -e "Screenly version: $(git rev-parse --abbrev-ref HEAD)@$(git rev-parse --short HEAD)\n$(lsb_release -a)" > ~/version.md

set +x

echo -n "Enter new hostname: "
read HOSTNAME

if [ "$HOSTNAME" != "" ]; then
  sudo hostnamectl set-hostname "$HOSTNAME"
  echo "Changed hostname to $HOSTNAME"
else 
  echo "Hostname unchanged "
fi

echo "Installation completed."

read -p "You need to reboot the system for the installation to complete. Would you like to reboot now? (y/N)" -n 1 -r -s REBOOT && echo
if [ "$REBOOT" == 'y' ]; then
  sudo reboot
fi

