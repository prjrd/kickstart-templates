install
url --url=http://repohost.raindrops.centos.org/centos/5/os/x86_64/
lang en_US.UTF-8
keyboard uk
network --device eth0 --bootproto dhcp
rootpw --iscrypted $1$1PhElNB7$y2.l.SG404Dv.LCN1OhQw0
authconfig --enableshadow --passalgo=sha512 --enablefingerprint
selinux --enforcing
timezone --utc Europe/London
bootloader --location=mbr --driveorder=sda
repo --name="CentOS" --baseurl=http://repohost.raindrops.centos.org/centos/5/os/x86_64/
repo --name="CentOS-Updates" --baseurl=http://repohost.raindrops.centos.org/centos/5/updates/x86_64/ 
zerombr yes
clearpart --all --initlabel
part /boot --fstype ext3 --size=250
part pv.2 --size=5000 --grow
volgroup VolGroup00 --pesize=32768 pv.2
logvol / --fstype ext4 --name=LogVol00 --vgname=VolGroup00 --size=1024 --grow
logvol swap --fstype swap --name=LogVol01 --vgname=VolGroup00 --size=256 --grow --maxsize=512
reboot
%packages
@core
