require recipes-bsp/u-boot/u-boot-nxp.inc

# URL ?= "git://source.codeaurora.cn/external/autobsps32/u-boot;protocol=https"
URL ?= "git://git@gitlab.enjoymove.cn/rmu-linux/u-boot.git;protocol=ssh"
# BRANCH ?= "${RELEASE_BASE}-${PV}"
BRANCH ??= "dev"
SRC_URI_prepend = "${URL};branch=${BRANCH}"

# SRCREV = "7eba18e1c0b994180e173e9343c7fe50819d9732"
SRCREV = "09a370793108deea8dee958164734b4d086fa6d8"
