SUMMARY = "bitbake-layers recipe"
DESCRIPTION = "Recipe created by bitbake-layers"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

URL ?= "git://git@gitlab.enjoymove.cn/rmu-linux/libembus.git;protocol=ssh"
BRANCH ??= "dev-test"
SRC_URI = "${URL};branch=${BRANCH} \
           file://embus.sh \
"

SRCREV = "20fa200b8082ddb7bfe0f4d57aff881b16f12159"

DEPENDS = "zeromq"

S = "${WORKDIR}/git"

inherit cmake

inherit update-rc.d

INITSCRIPT_NAME = "embus.sh"
INITSCRIPT_PARAMS = "start 89 S ."
RDEPENDS_${PN} = "initscripts"
CONFFILES_${PN} += "${sysconfdir}/init.d/embus.sh"

do_install_append () {
    if ${@bb.utils.contains('DISTRO_FEATURES', 'sysvinit', 'true', 'false', d)}; then
        install -d ${D}${sysconfdir}/init.d
        install -m 755 ${WORKDIR}/embus.sh ${D}${sysconfdir}/init.d/embus.sh
    fi
}

INSANE_SKIP_${PN}-dev += "dev-elf"
INSANE_SKIP_${PN} += "build-deps"
