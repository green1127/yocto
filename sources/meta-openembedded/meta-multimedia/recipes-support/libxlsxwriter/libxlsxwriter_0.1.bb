SUMMARY = "libxlsxwriter package"
SECTION = "libxlsxwriter"
LICENSE = "CLOSED"

URL ?= "git://git@gitlab.enjoymove.cn/rmu-linux/libxlsxwriter.git;protocol=ssh"
BRANCH ??= "dev"
SRC_URI = "${URL};branch=${BRANCH}"
SRCREV = "9fef0ccb45000fc872610cd18cb2a1812e853992"

DEPENDS = "zlib"


inherit cmake

S = "${WORKDIR}/git"


EXTRA_OECMAKE = "-DBUILD_SHARED_LIBS=ON \
"

do_install_append() {

       install -d ${D}${libdir}/

       install -D  ${WORKDIR}/build/libxlsxwriter.so.5 ${D}${libdir}/libxlsxwriter.so.5
       cd ${D}${libdir}/
       ln -sf  libxlsxwriter.so.5  libxlsxwriter.so
}

FILES_${PN} +="${libdir}/*.so"

FILES_${PN}-dev +="${libdir}/*.so"

