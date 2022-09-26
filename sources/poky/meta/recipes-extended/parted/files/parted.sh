#!/bin/sh
state=`head -1 /etc/parted.conf`
if [ "$state" = "uninitionalized" ]; then
    # resize part for root directory
    parted -s /dev/mmcblk0 resizepart 2 1222MB
    resize2fs /dev/mmcblk0p2
    # make part for the remaining space
    parted -s /dev/mmcblk0 mkpart primary fat32 1222MB 100%
    mkdosfs /dev/mmcblk0p3
    mount /dev/mmcblk0p3 /data

    echo "initionalized" > /etc/parted.conf
    exit 0
fi
