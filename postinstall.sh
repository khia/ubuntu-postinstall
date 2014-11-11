#!/bin/bash
set -e

DOCKER_LOCATION=/var/lib/docker

echo "Install nvidia drivers"
apt-get update
apt-get install -fqy libvdpau1 acpi bumblebee-nvidia nvidia-319 nvidia-settings-319
apt-get install -fqy primus primus-libs-ia32

echo "Install mtpfs for android phone"
apt-get install -fqy mtpfs

echo "configure intel+nvidia combo card"
sed -i "s/^\(Driver\)=.*/\1=nvidia/" /etc/bumblebee/bumblebee.conf
sed -i "s/^\(KernelDriver\)=.*/\1=nvidia/" /etc/bumblebee/bumblebee.conf
sed -i "s/^\(PMMethod\)=.*/\1=bbswitch/" /etc/bumblebee/bumblebee.conf

echo "fix acpi settings"
sed -i "s/^\(GRUB_CMDLINE_LINUX_DEFAULT\)=.*/\1=\"quiet splash acpi_osi=Linux\"/" /etc/default/grub
sed -i "s/^\(GRUB_CMDLINE_LINUX\)=.*/\1=\"acpi_backlight=vendor\"/" /etc/default/grub
update-grub

echo "fix bluetooth"
sed -i "s/^\(EnableGatt\) =.*/\1 = true/" /etc/bluetooth/main.conf
echo "options ath9k btcoex_enable=1" > /etc/modprobe.d/ath9k.conf

echo "improve battery live"
cat <<EOF > /etc/pm/power.d/power
#!/bin/sh

# Shell script to reduce energy consumption when running battery. Place
# it in /etc/pm/power.d/ and give execution rights.

#if on_ac_power; then
# Put specific AC power config here
#else
# Put specific Battery power config here
#fi

# Common Settings

echo "Enable Laptop-Mode disk writing"
echo 5 > /proc/sys/vm/laptop_mode

echo "Turning of NMI watchdog"
for foo in /proc/sys/kernel/nmi_watchdog;
do echo 0 > $foo;
done

echo "Set SATA channel to power saving"
for foo in /sys/class/scsi_host/host*/link_power_management_policy;
#do echo "min_power" > $foo;
#do echo "medium_power" > $foo;
#do echo "max_performance" > $foo;
done

echo "Activate USB autosuspend"
# Autosuspend for USB device Bluetooth USB Host Controller [Atheros Communications]
echo 'auto' > '/sys/bus/usb/devices/3-5/power/control';
# Autosuspend for USB device Touchscreen [ELAN]
echo 'auto' > '/sys/bus/usb/devices/3-10/power/control';
# Autosuspend for USB device USB2.0-CRW [Generic]
echo 'auto' > '/sys/bus/usb/devices/3-8/power/control';

echo "Activate PCI autosuspend"
for foo in /sys/bus/pci/devices/*/power/control;
do echo auto > $foo;
done

echo "Activate audio card power saving"
echo '1' > '/sys/module/snd_hda_intel/parameters/power_save';

echo "Set VM Writeback timeout"
echo '1500' > '/proc/sys/vm/dirty_writeback_centisecs';

echo "Turn off WOL"
ethtool -s p3p1 wol d;

EOF
chmod +x /etc/pm/power.d/power

echo "remove bloatware"
apt-get remove unity-lens-shopping unity-lens-music unity-lens-video unity-scope-video-remote unity-scope-musicstores

# install indicator-privacy to disable online search
#add-apt-repository ppa:diesch/testing
#apt-get update
#apt-get install indicator-privacy

echo "Add the docker group if it doesn't already exist."
sudo groupadd docker

# install docker
#apt-get install linux-image-extra-`uname -r`
sudo sh -c "wget -qO- https://get.docker.io/gpg | apt-key add -"
sudo sh -c "echo deb http://get.docker.io/ubuntu docker main\
> /etc/apt/sources.list.d/docker.list"
sudo apt-get update
sudo apt-get install -fqy lxc-docker

# Add the connected user "${USERNAME}" to the docker group.
# Change the user name to match your preferred user.
# You may have to logout and log back in again for
# this to take effect.
echo 'Please run manually following command'
echo 'sudo gpasswd -a ${USERNAME} docker'

echo "Reconfigure the docker daemon."
sudo service docker stop
if [ ! -d ${DOCKER_LOCATION} ]; then
  sudo mv /var/lib/docker ${DOCKER_LOCATION}
fi
sudo mkdir -p ${DOCKER_LOCATION}/tmp

cat <<EOF > /etc/default/docker
DOCKER_OPTS="-g ${DOCKER_LOCATION}"
export TMPDIR="${DOCKER_LOCATION}/tmp"
EOF
sudo service docker start

echo "install some additional packages"
apt-get install -fqy git xpra emacs24 htop sshfs curl git cpp mercurial tree pandoc gufw w3m sqlite3 gimp traceroute meld editorconfig gnupg2 silversearcher-ag wireshark gitg

############################
echo "Remove ubuntu spyware"
####

# Block connections to Ubuntu's ad server, just in case
if ! grep -q productsearch.ubuntu.com /etc/hosts; then
  echo -e "\n127.0.0.1 productsearch.ubuntu.com" | sudo tee -a /etc/hosts >/dev/null
fi

# remove amazon from dash
rm -rf /usr/share/applications/ubuntu-amazon-default.desktop

# disable error reporting to Ubuntu
sed -i '/^enabled=/s/=.*/=0/' /etc/default/apport
