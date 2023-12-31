HOMEPAGE = "http://www.alumnit.ca/wiki/?WvDial"
DESCRIPTION = "WvDial is a program that makes it easy to connect your Linux workstation to the Internet."

LICENSE = "LGPLv2"
LIC_FILES_CHKSUM = "file://COPYING.LIB;md5=55ca817ccb7d5b5b66355690e9abc605"

inherit pkgconfig update-rc.d

INITSCRIPT_NAME = "wvdial"
INITSCRIPT_PARAMS = "defaults 99"

DEPENDS = "wvstreams"
RDEPENDS_${PN} = "ppp"

SRC_URI = "https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/${BPN}/${BP}.tar.bz2 \
           file://ppp0-uptime-test.sh \
           file://wvdial.conf \
           file://wvdial.init \
           file://typo_pon.wvdial.1.patch \
           file://musl-support.patch \
          "
SRC_URI[md5sum] = "37e9a2d664effe4efd44c0e1a20136de"
SRC_URI[sha256sum] = "99906d9560cbdbc97e1855e7b0a7169f1e11983be3ac539140423f09debced82"

COMPATIBLE_HOST_libc-musl = "null"
EXTRA_OEMAKE = ""
export WVLINK="${LD}"

PARALLEL_MAKE = ""

do_configure() {
    sed -i 's/LDFLAGS+=-luniconf/LIBS+=-luniconf/' ${S}/Makefile
}

do_install() {
    install -d ${D}${sysconfdir}
    install -m 644 ${WORKDIR}/wvdial.conf ${D}${sysconfdir}/

    if ${@bb.utils.contains('DISTRO_FEATURES', 'sysvinit', 'true', 'false', d)}; then
        install -d ${D}${sysconfdir}/init.d
        install -m 0755 ${WORKDIR}/wvdial.init ${D}${sysconfdir}/init.d/wvdial
    fi

    install -d ${D}${sysconfdir}/init.d
    install -m 755 ${WORKDIR}/ppp0-uptime-test.sh ${D}${sysconfdir}/init.d/ppp0-uptime-test.sh

    oe_runmake prefix=${D}/usr PPPDIR=${D}/etc/ppp/peers install
}
