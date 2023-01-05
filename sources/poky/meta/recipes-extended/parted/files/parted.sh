#!/bin/sh
state=`head -1 /etc/parted.conf`
if [ "$state" = "uninitionalized" ]; then
    # resize part for root directory
    parted -s /dev/mmcblk0 resizepart 2 1222MB
    resize2fs /dev/mmcblk0p2

    parted -s /dev/mmcblk0 mkpart extended 1222MB 100%
    parted -s /dev/mmcblk0 mkpart logic fat32 1222MB 1288MB
    parted -s /dev/mmcblk0 mkpart logic ext4 1288mB 2510MB

    mkdosfs /dev/mmcblk0p5
    mkfs.ext4 /dev/mmcblk0p6 -Fq

    # make part for the remaining space
    parted -s /dev/mmcblk0 mkpart logic fat32 2550MB 100%
    mkdosfs /dev/mmcblk0p7
#    mount /dev/mmcblk0p7 /data

    # make part for SSD
    umount /ssdp0
    parted -s /dev/nvme0n1 rm 1
    parted -s /dev/nvme0n1 mkpart primary ext4 2048s 100%
    mkfs.ext4 /dev/nvme0n1p1 -Fq
    mount /dev/nvme0n1p1 /ssdp0

    echo "initionalized" > /etc/parted.conf
    exit 0
fi
