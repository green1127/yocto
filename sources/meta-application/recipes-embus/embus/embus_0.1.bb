SUMMARY = "bitbake-layers recipe"
DESCRIPTION = "Recipe created by bitbake-layers"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

URL ?= "git://git@gitlab.enjoymove.cn/rmu-linux/libembus.git;protocol=ssh"
BRANCH ??= "dev-test"
SRC_URI = "${URL};branch=${BRANCH} \
           file://embus.init \
"

SRCREV = "f4a6809586f5a4ffe98bef28c2c9d687afde1421"

DEPENDS = "zeromq"

S = "${WORKDIR}/git"

inherit cmake

inherit update-rc.d

INITSCRIPT_NAME = "embus"
INITSCRIPT_PARAMS = "defaults 98"

TEST_DIR = "/opt/test"

do_install_append () {
    install -d ${D}${TEST_DIR}
    mv ${D}${bindir}/embustest ${D}${TEST_DIR}
    mv ${D}${bindir}/udstest ${D}${TEST_DIR}

    if ${@bb.utils.contains('DISTRO_FEATURES', 'sysvinit', 'true', 'false', d)}; then
        install -d ${D}${sysconfdir}/init.d
        install -m 755 ${WORKDIR}/embus.init ${D}${sysconfdir}/init.d/embus
    fi
}

FILES_${PN} += "${TEST_DIR}/"

INSANE_SKIP_${PN}-dev += "dev-elf"
INSANE_SKIP_${PN} += "build-deps"
