SUMMARY = "ota test application"
SECTION = "ota test"
LICENSE = "MIT"

LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"


URL ?= "git://git@gitlab.enjoymove.cn/rmu-linux/ota.git;protocol=ssh"
BRANCH ??= "dev"
SRC_URI = "${URL};branch=${BRANCH}"
SRCREV = "13bb4718ba46db930cbcdcd2535ac7a1923fd9e1"


S = "${WORKDIR}/git"

inherit cmake

do_install_append() {

       install -d ${D}${bindir}/
       install -m 0755 ${WORKDIR}/build/test/emota ${D}${bindir}/

       install -d ${D}${libdir}/
      # install -m 0755 ${WORKDIR}/build/lib/libota.so.0.1.1 ${D}${libdir}/libota.so.0.1.1
       install -D  ${WORKDIR}/build/lib/libota.so.0.1.1 ${D}${libdir}/libota.so.0.1.1
       cd ${D}${libdir}/
       ln -sf libota.so.0.1.1   libota.so.0
       ln -sf libota.so.0   libota.so
}

FILES_${PN} +="${libdir}/*.so"

FILES_${PN}-dev +="${libdir}/*.so"

FILES_SOLIBSDEV += ""

INSANE_SKIP_${PN} = "dev-so"


EXTRA_OECMAKE = " \
    -DCMAKE_SKIP_RPATH=TRUE \
"


