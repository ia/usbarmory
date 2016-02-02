#!/usr/bin/env bash

set -e;
set -x;

sudo  parted  /dev/sdc  --script  mklabel  msdos
sudo  parted  /dev/sdc  --script  mkpart   primary ext4 5M 50%
sudo  sync
sudo  mkfs.ext4 -m 0 -L USBARMORY /dev/sdc1

sudo  mount    /dev/sdc1      /mnt/tmp
sudo  cp -afr  ubuntu-core-14.10-core-armhf_rootfs_4.0.2/*  /mnt/tmp/
sudo  umount   /mnt/tmp
sudo  sync
sudo  dd if=u-boot-2015.04/u-boot.imx of=/dev/sdc bs=512 seek=2 conv=fsync
sudo  sync

