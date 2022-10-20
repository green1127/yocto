SUMMARY = "bitbake-layers recipe"
DESCRIPTION = "Recipe created by bitbake-layers"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

URL ?= "git://git@gitlab.enjoymove.cn/rmu-linux/embusd.git;protocol=ssh"
BRANCH ??= "dev"
SRC_URI = "${URL};branch=${BRANCH} \
           file://embusd.init \
"

SRCREV = "cc505c4ca7b21f5d7166d1f3b5bf752ff03e6b3e"

DEPENDS = "zeromq jsoncpp spdlog"

S = "${WORKDIR}/git"

inherit cmake

inherit update-rc.d

INITSCRIPT_NAME = "embus"
INITSCRIPT_PARAMS = "defaults 99"

do_install_append () {
    if ${@bb.utils.contains('DISTRO_FEATURES', 'sysvinit', 'true', 'false', d)}; then
        install -d ${D}${sysconfdir}/init.d
        install -m 0755 ${WORKDIR}/embusd.init ${D}${sysconfdir}/init.d/embus
    fi
}

FILES_${PN} += "/opt"

INSANE_SKIP_${PN}-dev += "dev-elf"
INSANE_SKIP_${PN} += "build-deps"
