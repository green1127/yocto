SUMMARY = "bitbake-layers recipe"
DESCRIPTION = "Recipe created by bitbake-layers"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

URL ?= "git://git@gitlab.enjoymove.cn/rmu-linux/libembus.git;protocol=ssh"
BRANCH ??= "dev-test"
SRC_URI = "${URL};branch=${BRANCH} \
           file://embus.sh \
"

SRCREV = "7ab2dc057a1c9f1fdcf9866e49b0944c321d62e2"

DEPENDS = "zeromq"

S = "${WORKDIR}/git"

inherit cmake

inherit update-rc.d

INITSCRIPT_NAME = "embus.sh"
INITSCRIPT_PARAMS = "start 89 S ."
RDEPENDS_${PN} = "initscripts"
CONFFILES_${PN} += "${sysconfdir}/init.d/embus.sh"

TEST_DIR = "/opt/test"

do_install_append () {
    install -d ${D}${TEST_DIR}
    mv ${D}${bindir}/embustest ${D}${TEST_DIR}
    mv ${D}${bindir}/udstest ${D}${TEST_DIR}

    if ${@bb.utils.contains('DISTRO_FEATURES', 'sysvinit', 'true', 'false', d)}; then
        install -d ${D}${sysconfdir}/init.d
        install -m 755 ${WORKDIR}/embus.sh ${D}${sysconfdir}/init.d/embus.sh
    fi
}

FILES_${PN} += "${TEST_DIR}/"

INSANE_SKIP_${PN}-dev += "dev-elf"
INSANE_SKIP_${PN} += "build-deps"
