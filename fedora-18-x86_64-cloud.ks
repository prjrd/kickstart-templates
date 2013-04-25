# This is a basic Fedora 18 spin designed to work in OpenStack and other
# private cloud environments. It's configured with cloud-init so it will
# take advantage of ec2-compatible metadata services for provisioning
# ssh keys. That also currently creates an ec2-user account; we'll probably
# want to make that something generic by default. The root password is empty
# by default.
#
# Note that unlike the standard F18 install, this image has /tmp on disk
# rather than in tmpfs, since memory is usually at a premium.

lang en_US.UTF-8
keyboard us
timezone --utc America/New_York

auth --useshadow --enablemd5
selinux --enforcing

# this is actually not used, but a static firewall
# matching these rules is generated below.
firewall --service=ssh

bootloader --timeout=0 --location=mbr --driveorder=sda

network --bootproto=dhcp --device=eth0 --onboot=on
services --enabled=network,sshd,rsyslog,iptables,cloud-init,cloud-init-local,cloud-config,cloud-final

part biosboot --fstype=biosboot --size=1 --ondisk sda
part / --size 10000 --fstype ext4 --ondisk sda

# Repositories
repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-18&arch=$basearch
repo --name=fedora-updates --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f18&arch=$basearch 


# Package list.
%packages --nobase
@core
kernel

# cloud-init does magical things with EC2 metadata, including provisioning
# a user account with ssh keys.
cloud-init

# Not needed with pv-grub (as in EC2). Would be nice to have
# something smaller for F19 (syslinux?), but this is what we have now.
grub2

# Needed initially, but removed below.
firewalld

# Basic firewall. If you're going to rely on your cloud service's
# security groups you can remove this.
iptables-services

# cherry-pick a few things from @standard
tmpwatch
tar
rsync

# Some things from @core we can do without in a minimal install
-biosdevname
-plymouth
-NetworkManager
-polkit

%end



%post --erroronfail

echo -n "Writing fstab"
cat <<EOF > /etc/fstab
LABEL=_/   /         ext4    defaults        1 1
EOF
echo .

echo -n "Grub tweaks"
echo GRUB_TIMEOUT=0 > /etc/default/grub
sed -i 's/^set timeout=5/set timeout=0/' /boot/grub2/grub.cfg
sed -i '1i# This file is for use with pv-grub; legacy grub is not installed in this image' /boot/grub/grub.conf
sed -i 's/^timeout=5/timeout=0/' /boot/grub/grub.conf
sed -i 's/^default=1/default=0/' /boot/grub/grub.conf
sed -i '/splashimage/d' /boot/grub/grub.conf
# need to file a bug on this one
sed -i 's/root=.*/root=LABEL=_\//' /boot/grub/grub.conf
echo .
if ! [[ -e /boot/grub/menu.lst ]]; then
  echo -n "Linking menu.lst to old-style grub.conf for pv-grub"
  ln /boot/grub/grub.conf /boot/grub/menu.lst
  ln -sf /boot/grub/grub.conf /etc/grub.conf
fi

# setup systemd to boot to the right runlevel
echo -n "Setting default runlevel to multiuser text mode"
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target
echo .

# If you want to remove rsyslog and just use journald, also uncomment this.
#echo -n "Enabling persistent journal"
#mkdir /var/log/journal/ 
#echo .

# this is installed by default but we don't need it in virt
echo "Removing linux-firmware package."
yum -C -y remove linux-firmware

# Remove firewalld; was supposed to be optional in F18, but is required to
# be present for install/image building.
echo "Removing firewalld."
yum -C -y remove firewalld

# Non-firewalld-firewall
echo -n "Writing static firewall"
cat <<EOF > /etc/sysconfig/iptables
# Simple static firewall loaded by iptables.service. Replace
# this with your own custom rules, run lokkit, or switch to 
# shorewall or firewalld as your needs dictate.
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate NEW -m tcp -p tcp --dport 22 -j ACCEPT
#-A INPUT -m conntrack --ctstate NEW -m tcp -p tcp --dport 80 -j ACCEPT
#-A INPUT -m conntrack --ctstate NEW -m tcp -p tcp --dport 443 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
echo .

# Because memory is scarce resource in most cloud/virt environments,
# and because this impedes forensics, we are differing from the Fedora
# default of having /tmp on tmpfs.
echo "Disabling tmpfs for /tmp."
systemctl mask tmp.mount

# appliance-creator does not make this important file.
if [ ! -e /etc/sysconfig/kernel ]; then
echo "Creating /etc/sysconfig/kernel."
cat <<EOF > /etc/sysconfig/kernel
# UPDATEDEFAULT specifies if new-kernel-pkg should make
# new kernels the default
UPDATEDEFAULT=yes

# DEFAULTKERNEL specifies the default kernel package type
DEFAULTKERNEL=kernel
EOF
fi

# Uncomment this if you want to use cloud init but suppress the creation
# of an "ec2-user" account. This will, in the absence of further config,
# cause the ssh key from a metadata source to be put in the root account.
#cat <<EOF > /etc/cloud/cloud.cfg.d/50_suppress_ec2-user_use_root.cfg
#users: []
#disable_root: 0
#EOF

echo "Zeroing out empty space."
# This forces the filesystem to reclaim space from deleted files
dd bs=1M if=/dev/zero of=/var/tmp/zeros || :
rm -f /var/tmp/zeros
echo "(Don't worry -- that out-of-space error was expected.)"

%end

