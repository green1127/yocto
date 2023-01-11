SUMMARY = "bitbake-layers recipe"
DESCRIPTION = "Recipe created by bitbake-layers"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

URL ?= "git://git@gitlab.enjoymove.cn/rmu-linux/libembus.git;protocol=ssh"
BRANCH ??= "dev-test"
SRC_URI = "${URL};branch=${BRANCH} \
           file://embus.init \
"

SRCREV = "cfb6ad25f138c1df889d9555c1ea9be4b6880bf5"

DEPENDS = "zeromq"

S = "${WORKDIR}/git"

inherit cmake

inherit update-rc.d

INITSCRIPT_NAME = "embus"
INITSCRIPT_PARAMS = "defaults 98"


do_install_append () {
    install -d ${D}${bindir}
   # mv ${D}${bindir}/embustest ${D}${TEST_DIR}
   # mv ${D}${bindir}/udstest ${D}${TEST_DIR}

    if ${@bb.utils.contains('DISTRO_FEATURES', 'sysvinit', 'true', 'false', d)}; then
        install -d ${D}${sysconfdir}/init.d
        install -m 755 ${WORKDIR}/embus.init ${D}${sysconfdir}/init.d/embus
    fi
}

FILES_${PN} += "${bindir}/"

INSANE_SKIP_${PN}-dev += "dev-elf"
INSANE_SKIP_${PN} += "build-deps"
