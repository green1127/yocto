require recipes-bsp/u-boot/u-boot-nxp.inc

# URL ?= "git://source.codeaurora.cn/external/autobsps32/u-boot;protocol=https"
URL ?= "git://git@gitlab.enjoymove.cn/rmu-linux/u-boot.git;protocol=ssh"
# BRANCH ?= "${RELEASE_BASE}-${PV}"
BRANCH ??= "dev"
SRC_URI_prepend = "${URL};branch=${BRANCH}"

# SRCREV = "7eba18e1c0b994180e173e9343c7fe50819d9732"
SRCREV = "bcec06dfd15b83408c50526b9bf51fc9e2379da4"
