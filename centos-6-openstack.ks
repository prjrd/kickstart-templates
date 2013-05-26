install
url --url=http://repohost.raindrops.centos.org/centos/6/os/x86_64/
lang en_US.UTF-8
keyboard uk
network --device eth0 --bootproto dhcp
rootpw --iscrypted $1$4kX33zRO$1U/TwBtZFjGA7WOv/NdKK/
firewall --service=ssh
authconfig --enableshadow --passalgo=sha512 --enablefingerprint
selinux --enforcing
timezone --utc Europe/London
bootloader --location=mbr --driveorder=sda
repo --name="CentOS" --baseurl=http://repohost.raindrops.centos.org/centos/6/os/x86_64/ --cost=100
repo --name="EPEL" --baseurl=http://repohost.raindrops.centos.org/epel/6/x86_64/ --cost=100
zerombr yes
clearpart --all --initlabel
part /boot --fstype ext3 --size=250
part pv.2 --size=5000 --grow
volgroup VolGroup00 --pesize=32768 pv.2
logvol / --fstype ext4 --name=LogVol00 --vgname=VolGroup00 --size=1024 --grow
logvol swap --fstype swap --name=LogVol01 --vgname=VolGroup00 --size=256 --grow --maxsize=512
reboot
%packages
@Base
@Core
cloud-init
%end
%post --log=/root/post.log
echo "NOZEROCONF=yes" >> /etc/sysconfig/network
echo "S0:2345:respawn:/sbin/agetty ttyS0 115200 linux" >> /etc/inittab
sed -i "s/^ACTIVE_CONSOLES=\/dev\/tty\[1-6\]/ACTIVE_CONSOLES=\/dev\/tty1/" /etc/sysconfig/init
sed -i "/HWADDR/d" /etc/sysconfig/network-scripts/ifcfg-eth*
rm -f /etc/udev/rules.d/70-persistent-net.rules
for f in /etc/grub.conf /boot/grub/menu.lst /boot/grub/grub.conf; do
  sed -i "s/^serial.*$/serial –unit=0 –speed=115200/" ${f}
  sed -i "s/^terminal.*$/terminal –timeout=10 console serial/" ${f}
  sed -i "s/console=ttyS0,115200/console=tty0 console=ttyS0,115200n8/" ${f}
done
useradd ec2-user
echo -e 'ec2-user\tALL=(ALL)\tNOPASSWD: ALL' >> /etc/sudoers
%end
