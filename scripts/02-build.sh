#!/usr/bin/env bash


set -e;
set -x;


# ==== ==== ==== ==== ==== ==== ==== ==== #
# TODO:


# ==== ==== ==== ==== ==== ==== ==== ==== #
# set static configuration

UBOOT="u-boot-2015.04"

KERNEL="4.1.3"
KVERSION="-1-usbarmory"
#DIST="vivid"
#DIST="jessie"
DIST="fedora"

#CORE="ubuntu-core-15.04-core-armhf"
#CORE="debian-base-8-core-armhf"
CORE="fedora-mini-22-core-armhf"

IMGZ="Fedora-Minimal-armhfp-22-3-sda.raw.xz"
IMG="Fedora-Minimal-armhfp-22-3-sda.raw"
LOOP="/dev/mapper/loop0"

CONFIG="${CORE}/usbarmory_linux-${KERNEL}.config"

export CROSS_COMPILE=arm-linux-gnueabihf-
export ARCH=arm
export NCPU=9


# ==== ==== ==== ==== ==== ==== ==== ==== #
# set dynamic variables


file_uboot="${UBOOT}.tar.bz2"
file_kernel="linux-${KERNEL}.tar.xz"
file_core="${CORE}.tar.gz"

dir_uboot="${UBOOT}"
dir_kernel="linux-${KERNEL}"
dir_core="${CORE}_rootfs"
dir_core_conf="${CORE}"
dir_core_kern="${dir_core}_${KERNEL}"


# ==== ==== ==== ==== ==== ==== ==== ==== #
# clean up
uarm_clean() {
sudo rm -rf  linux-4.1.1  u-boot-2015.04  ubuntu-core-15.04-core-armhf_*  debian-base-8-core-armhf_*  fedora-micro-22-3-core-armhf_*
}


# ==== ==== ==== ==== ==== ==== ==== ==== #
# prepare ripped off fedora armhf root fs micro tarball
uarm_fedcore() {
# based on:
# - http://arm.fedoraproject.org/
# - http://linux-exynos.org/wiki/Installing_a_rootfs#Fedora

xz -k -d ${IMGZ}
sudo kpartx -a ${IMG}
mkdir ${dir_core}

sudo  mount  ${LOOP}p3  ${dir_core}
sudo  mount  ${LOOP}p1  ${dir_core}/boot

sudo  mount  --bind  /dev      ${dir_core}/dev
sudo  mount  --bind  /dev/pts  ${dir_core}/dev/pts
sudo  mount  --bind  /sys      ${dir_core}/sys
sudo  mount  --bind  /proc     ${dir_core}/proc

sudo  cp  /etc/resolv.conf              ${dir_core}/etc/resolv.conf
sudo  sed  -i  's,\$basearch,armhfp,g'  ${dir_core}/etc/yum.repos.d/*.repo

echo  "# UNCONFIGURED FSTAB FOR BASE SYSTEM" | sudo tee ${dir_core}/etc/fstab

sudo  cp  /usr/bin/qemu-arm-static  ${dir_core}/usr/bin

sudo  chroot  ${dir_core}    dnf list installed

sudo  chroot  ${dir_core}    dnf remove $(cat ~/web/dropbox/usbarmory/fedpkgs_remove_mini.txt)
#sudo  chroot  ${dir_core}    dnf remove $(cat ~/web/dropbox/usbarmory/fedpkgs_remove_micro.txt)

sudo  chroot  ${dir_core}    dnf clean all

echo -ne "" | sudo tee ${dir_core}/etc/resolv.conf

sudo  umount  ${dir_core}/dev/pts
sudo  umount  ${dir_core}/dev
sudo  umount  ${dir_core}/sys
sudo  umount  ${dir_core}/proc
sudo  umount  ${dir_core}/boot

sudo  rm  ${dir_core}/usr/bin/qemu-arm-static

ret="`pwd`"
cd ${dir_core}
sudo  tar  czf  ${ret}/${file_core}  *
cd ${ret}

sudo  umount  ${dir_core}

sudo  dmsetup  remove  ${LOOP}p1
sudo  dmsetup  remove  ${LOOP}p2
sudo  dmsetup  remove  ${LOOP}p3

sudo  losetup  -d /dev/loop0

sudo  rm  -rf  "${dir_core}" "${IMG}"
}


# ==== ==== ==== ==== ==== ==== ==== ==== #
# prepare base debian armhf root fs tarball
uarm_debbase() {
mkdir ${dir_core}

sudo  qemu-debootstrap  --arch=armhf  ${DIST}  ${dir_core}  http://ftp.debian.org/debian/

echo -ne "" | sudo tee ${dir_core}/etc/resolv.conf
sudo rm ${dir_core}/usr/bin/qemu-arm-static
# TODO: enything else?

ret="`pwd`"
cd ${dir_core}
sudo  tar  czf  ${ret}/${file_core}  *
cd ${ret}

sudo  rm  -rf  "${dir_core}"
}


# ==== ==== ==== ==== ==== ==== ==== ==== #
# unpack tarballs
uarm_unpack() {
mkdir ${dir_core}

tar xf ${file_uboot}
tar xf ${file_kernel}

sudo tar xf ${file_core} -C ${dir_core}
}


# ==== ==== ==== ==== ==== ==== ==== ==== #
# set up root fs
uarm_rootfs() {
### package management
pkgs_base="openssh-server whois fake-hwclock bash bash-completion perl-modules apt-utils kmod sudo ntpdate vim locales less cpufrequtils iputils-ping net-tools ifupdown file dialog"
# pkgs_extra="tcpdump"

# TODO: fedora: modprobe.d < options; modules-load.d < modules; *.repo : base; net:
#https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/sec-Using_the_NetworkManager_Command_Line_Tool_nmcli.html
#https://docs.fedoraproject.org/en-US/Fedora/20/html/Networking_Guide/sec-Connecting_to_a_Network_Using_nmcli.html
#http://ask.xmodulo.com/configure-static-ip-address-centos7.html
# sudo:
#usermod  usbarmory  -a  -G wheel

# iptables -t nat -A POSTROUTING -s 10.0.0.1/32 -o wlan0 -j MASQUERADE

# TODO: mount --bind ..

sudo  cp  /usr/bin/qemu-arm-static               ${dir_core}/usr/bin/qemu-arm-static

if [ "${DIST}" != "fedora" ]; then
sudo  mv  ${dir_core}/etc/apt/sources.list       ${dir_core}/etc/apt/sources.list.disabled
sudo  cp  ${dir_core_conf}/sources.list.${DIST}  ${dir_core}/etc/apt/sources.list
sudo  cp  ${dir_core_conf}/00bloatware           ${dir_core}/etc/apt/apt.conf.d/00bloatware
sudo  cp  ${dir_core_conf}/ddebs.list.${DIST}    ${dir_core}/etc/apt/sources.list.d/ddebs.list || true
fi;

echo "nameserver 8.8.8.8" | sudo tee ${dir_core}/etc/resolv.conf

if [ "${DIST}" != "fedora" ]; then
sudo  chroot ${dir_core} apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ECDCAD72428D7C01
sudo  chroot ${dir_core} apt-get update
sudo  chroot ${dir_core} apt-get install -y ${pkgs_base} ${pkgs_extra}
sudo  chroot ${dir_core} locale-gen en_US en_US.UTF-8 # ru_RU ru_RU.UTF-8
sudo  chroot ${dir_core} dpkg-reconfigure locales
fi;

sudo  chroot ${dir_core} /usr/sbin/useradd -s /bin/bash -p `mkpasswd -m sha-512 usbarmory` -m usbarmory

if [ "${DIST}" = "utopic" ]; then
sudo  cp  ${dir_core_conf}/ttymxc0.conf          ${dir_core}/etc/init/ttymxc0.conf
else
sudo  chroot  ${dir_core}  systemctl mask getty-static.service
echo  -e "\nUseDNS no" | sudo tee -a ${dir_core}/etc/ssh/sshd_config
fi;

echo "tmpfs  /tmp  tmpfs  defaults  0 0" | sudo tee ${dir_core}/etc/fstab

### modules
echo -ne "\n# USB Armory stuff\n\n## LED blink\nledtrig_heartbeat\n\n## CI HDRC i.MX USB binding\nci_hdrc_imx\n\n## USB ethernet\ng_ether\n\n## USB storage\n#g_mass_storage\n\n" | sudo tee -a ${dir_core}/etc/modules
echo "options g_ether  use_eem=0  dev_addr=1a:55:89:a2:69:41  host_addr=1a:55:89:a2:69:42" | sudo tee -a ${dir_core}/etc/modprobe.d/usbarmory.conf

### network
echo -e 'allow-hotplug usb0\niface usb0 inet static\n  address 10.0.0.1\n  netmask 255.255.255.0\n  gateway 10.0.0.2' | sudo tee -a ${dir_core}/etc/network/interfaces
echo -e "127.0.1.1\tusbarmory" | sudo tee -a ${dir_core}/etc/hosts
echo "usbarmory" | sudo tee ${dir_core}/etc/hostname

### security
echo "usbarmory  ALL=(ALL) NOPASSWD: ALL" | sudo tee -a ${dir_core}/etc/sudoers

### configure
# change bashrc prompt, e.g. : ⇢
# update time zone
#if [ "${DIST}" != "fedora" ]; then
#sudo  chroot  ${dir_core}  dpkg-reconfigure  tzdata
#fi;

### clean up
sudo rm ${dir_core}/usr/bin/qemu-arm-static

### save out
sudo cp -afr ${dir_core} ${dir_core_kern}
}


# ==== ==== ==== ==== ==== ==== ==== ==== #
# set up kernel
uarm_kernel_build() {
cp  ${CONFIG}                                ${dir_kernel}/.config
cp  ${dir_core_conf}/imx53-usbarmory-*.dts*  ${dir_kernel}/arch/arm/boot/dts/

make  -j${NCPU}  -C ${dir_kernel}  uImage  LOADADDR=0x70008000  LOCALVERSION=${KVERSION}  modules  imx53-usbarmory-dflt.dtb  imx53-usbarmory-host.dtb  imx53-usbarmory-gpio.dtb
}

uarm_kernel_install() {
sudo  cp  ${dir_kernel}/arch/arm/boot/uImage                        ${dir_core_kern}/boot/
sudo  cp  ${dir_kernel}/arch/arm/boot/dts/imx53-usbarmory-*.dtb     ${dir_core_kern}/boot/

sudo  make  -j${NCPU}  -C ${dir_kernel}  CROSS_COMPILE=arm-linux-gnueabihf-  INSTALL_MOD_PATH=../${dir_core_kern}  ARCH=arm modules_install
}

uarm_kernel_pkg() {
# TODO: enable DEBUG CONFIG, change .config for snappy support

# deb:
#cp arch/arm/boot/dts/imx53-usbarmory-dflt.dtb  "$tmpdir/boot/imx53-usbarmory-dflt.dtb-$version"
#cp arch/arm/boot/dts/imx53-usbarmory-host.dtb  "$tmpdir/boot/imx53-usbarmory-host.dtb-$version"
#cp arch/arm/boot/dts/imx53-usbarmory-gpio.dtb  "$tmpdir/boot/imx53-usbarmory-gpio.dtb-$version"

# rpm:
#- mkspec: #echo 'make INSTALL_FW_PATH=$INSTALL_FW_PATH' firmware_install
#- mkspec:
#echo 'cp arch/arm/boot/dts/imx53-usbarmory-dflt.dtb  $RPM_BUILD_ROOT'"/boot/imx53-usbarmory-dflt.dtb-$KERNELRELEASE"
#echo 'cp arch/arm/boot/dts/imx53-usbarmory-host.dtb  $RPM_BUILD_ROOT'"/boot/imx53-usbarmory-host.dtb-$KERNELRELEASE"
#echo 'cp arch/arm/boot/dts/imx53-usbarmory-gpio.dtb  $RPM_BUILD_ROOT'"/boot/imx53-usbarmory-gpio.dtb-$KERNELRELEASE"
#+ Makefile: binrpm-pkg: --define "_arch armv7hl", $(UTS_MACHINE) armv7hl
#+ Makefile:
#	echo 0 > $(objtree)/.version
#	echo 0 > $(objtree)/.tmp_version

export DEBEMAIL="name AT mailbox"
export DEBFULLNAME="Full Name"

#make  -j${NCPU}  -C ${dir_kernel}  deb-pkg     KBUILD_IMAGE=uImage                LOADADDR=0x70008000  LOCALVERSION=${KVERSION}  KBUILD_DEBARCH=armhf  KDEB_PKGVERSION=${KERNEL}${KVERSION}  KDEB_CHANGELOG_DIST=${DIST}

make  -j${NCPU}  -C ${dir_kernel}  binrpm-pkg  KBUILD_IMAGE=arch/arm/boot/uImage  LOADADDR=0x70008000  LOCALVERSION=${KVERSION}

cp      ~/rpmbuild/RPMS/armv7hl/kernel-*.rpm kpkgs/fedora_*
rm -rf  ~/rpmbuild
}


# ==== ==== ==== ==== ==== ==== ==== ==== #
# set up bootloader
# http://www.denx.de/wiki/U-Boot/Documentation
uarm_uboot() {
sed -i 's,bootargs_default=root=/dev/mmcblk0p1,bootargs_default=root=/dev/mmcblk0p1 rootfstype=ext4,' ${dir_uboot}/include/configs/usbarmory.h
make  -C ${dir_uboot}  -j${NCPU}  distclean
make  -C ${dir_uboot}  -j${NCPU}  usbarmory_config
make  -C ${dir_uboot}  -j${NCPU}  ARCH=arm
# => saveenv
}


# ==== ==== ==== ==== ==== ==== ==== ==== #
# dump commands to set up storage
uarm_flash() {
dev_target="/dev/sdc"
mnt_target="/mnt/tmp"

echo -ne "\n
sudo  parted  ${dev_target}  --script  mklabel  msdos
sudo  parted  ${dev_target}  --script  mkpart   primary ext4 5M 50%
sudo  mkfs.ext4 -m 0 -L USBARMORY ${dev_target}1

sudo  mount    ${dev_target}1      ${mnt_target}
sudo  cp -afr  ${dir_core_kern}/*  ${mnt_target}
sudo  umount   ${mnt_target}
sudo  dd if=${dir_uboot}/u-boot.imx of=${dev_target} bs=512 seek=2 conv=fsync
"
}


# ==== ==== ==== ==== ==== ==== ==== ==== #
# main


if [ -z "${1}" ]; then
#uarm_clean

#uarm_fedcore
#uarm_debbase

#uarm_unpack

#uarm_rootfs

uarm_kernel_build
#uarm_kernel_build  &&  uarm_kernel_install
#uarm_kernel_build  &&  uarm_kernel_pkg

#uarm_uboot
#uarm_flash
else
	${1}
fi;


