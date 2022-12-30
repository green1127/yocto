SUMMARY = "Example of how to build an external Linux kernel module"
LICENSE = "GPLv2"

LIC_FILES_CHKSUM = "file://COPYING;md5=12f884d2ae1ff87c09e5b7ccc2c4ca7e"

inherit module

URL ?= "git://git@gitlab.enjoymove.cn/rmu-linux/vnet.git;protocol=ssh"
BRANCH ??= "dev"
SRC_URI = "${URL};branch=${BRANCH}"
SRCREV = "1fb9ebe870d9d040ced0d3e25c7710084cfb1004"

S = "${WORKDIR}/git/"

MODULES_DIR = "${base_libdir}/modules/${KERNEL_VERSION}/kernel/drivers"


module_do_install() {
    
     mkdir -p "${D}${MODULES_DIR}/net/vnet" 
    # install -d ${D}${MODULES_DIR}/net/vnet/
    # install -m 644 ${S}/vnet.ko  ${D}${MODULES_DIR}/net/vnet/
     install -D ${S}/vnet.ko   ${D}${MODULES_DIR}/net/vnet/vnet.ko

}


KERNEL_MODULE_AUTOLOAD += "vnet"


FILES_${PN} += "${base_libdir}/*"
FILES_${PN} += "${sysconfdir}/modules-load.d/*"

# The inherit of module.bbclass will automatically name module packages with
# "kernel-module-" prefix as required by the oe-core build environment.

PROVIDES += "kernel-module-vnet${KERNEL_MODULE_PACKAGE_SUFFIX}"
RPROVIDES_${PN} += "kernel-module-vnet${KERNEL_MODULE_PACKAGE_SUFFIX}"

#PROVIDES = " \
#        kernel-module-vnet${KERNEL_MODULE_PACKAGE_SUFFIX} \
#        "
#RPROVIDES_${PN} = " \
#        kernel-module-vnet${KERNEL_MODULE_PACKAGE_SUFFIX} \
#        "

COMPATIBLE_MACHINE = "gen1"

