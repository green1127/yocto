SUMMARY = "bitbake-layers recipe"
DESCRIPTION = "Recipe created by bitbake-layers"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

URL ?= "git://git@gitlab.enjoymove.cn/rmu-linux/embusd.git;protocol=ssh"
BRANCH ??= "dev"
SRC_URI = "${URL};branch=${BRANCH} \
           file://embusd.sh \
"

SRCREV = "cc505c4ca7b21f5d7166d1f3b5bf752ff03e6b3e"

DEPENDS = "zeromq jsoncpp spdlog"

S = "${WORKDIR}/git"

inherit cmake

inherit update-rc.d

INITSCRIPT_NAME = "embusd.sh"
INITSCRIPT_PARAMS = "start 89 S ."
RDEPENDS_${PN} = "initscripts"
CONFFILES_${PN} += "${sysconfdir}/init.d/embusd.sh"

do_install_append () {
    install -d ${D}${sysconfdir}/init.d
    install -m 755 ${WORKDIR}/embusd.sh ${D}${sysconfdir}/init.d/embusd.sh
}

FILES_${PN} += "/opt"

INSANE_SKIP_${PN}-dev += "dev-elf"
INSANE_SKIP_${PN} += "build-deps"
