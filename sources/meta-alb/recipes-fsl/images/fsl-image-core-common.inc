#
# Copyright 2018 NXP.
#

PACKAGES-CORE = "\
    packagegroup-core-ssh-openssh \
    bash \
    dosfstools \
    sysfsutils \
    sysstat \
    gdbserver \
    nfs-utils \
    lrzsz \
    glibc-utils \
"

PACKAGES-CORE_append_s32 = "\
    fbset-modes \
"

PACKAGES-CORE-ext2 = "\
    hdparm \
    e2fsprogs \
    e2fsprogs-badblocks \
    e2fsprogs-e2fsck \
    e2fsprogs-mke2fs \
    e2fsprogs-tune2fs \
    e2fsprogs-resize2fs \
"

PACKAGES-CORE-MISC = "\
    coreutils \
    devmem2 \
    elfutils \
    ethtool \
    file \
    iputils \
    kernel-modules \
    kmod \
    mdadm \
    netcat \
    net-tools \
    pkgconfig \
    procps \
    psmisc \
    strongswan \
    i2c-tools \
"

PACKAGES-CORE-MISC_append_fsl-lsch3 += "\
    merge-files \
"

PACKAGES-CORE-mtd = "\
    mtd-utils \
    mtd-utils-jffs2 \
    mtd-utils-ubifs \
"

PACKAGES-CORE-benchmark = "\
    iperf3 \
    iozone3 \
    lmbench \
    netperf \
"

PACKAGES-CORE-MISC += "\
    bridge-utils \
    inetutils \
    inetutils-ping \
    inetutils-ping6 \
    inetutils-hostname \
    inetutils-ifconfig \
    inetutils-logger \
    inetutils-traceroute \
    inetutils-ftp \
    inetutils-ftpd \
    inetutils-telnet \
    inetutils-telnetd \
    inetutils-inetd \
    inetutils-rsh \
    inetutils-rshd \
    libhugetlbfs \
    lmsensors-sensors \
    tcpdump \
    tcpreplay \
"

PACKAGES-CORE-MISC_append_fsl-lsch3 = "\
    iproute2 \
    iproute2-tc \
    iptables \
"

PACKAGES-CORE-DPAA2 = "\
    dce \
	restool \
"

PACKAGES-CORE-DBG = "\
	kexec \
	kdump \
	vmcore-dmesg \
	memtester \
"

PACKAGES-CORE-MISC_append_lx2160a = " ${PACKAGES-CORE-DPAA2} ${PACKAGES-CORE-DBG}"

IMAGE_INSTALL += "\
    ${PACKAGES-CORE} \
    ${PACKAGES-CORE-MISC} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'benchmark', '${PACKAGES-CORE-benchmark}', '',d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'ext2', '${PACKAGES-CORE-ext2}', '',d)} \
    ${@bb.utils.contains('DISTRO_FEATURES', 'mtd', '${PACKAGES-CORE-mtd}', '',d)} \
"
