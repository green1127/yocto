require glibc-common.inc
require glibc-ld.inc
require glibc-testing.inc

python () {
    opt_effective = "-O"
    for opt in d.getVar('SELECTED_OPTIMIZATION').split():
        if opt in ("-O0", "-O", "-O1", "-O2", "-O3", "-Os"):
            opt_effective = opt
    if opt_effective == "-O0":
        bb.fatal("%s can't be built with %s, try -O1 instead" % (d.getVar('PN'), opt_effective))
    if opt_effective in ("-O", "-O1", "-Os"):
        bb.note("%s doesn't build cleanly with %s, adding -Wno-error to SELECTED_OPTIMIZATION" % (d.getVar('PN'), opt_effective))
        d.appendVar("SELECTED_OPTIMIZATION", " -Wno-error")
}

DEPENDS = "virtual/${TARGET_PREFIX}gcc libgcc-initial linux-libc-headers"

PROVIDES = "virtual/libc"
PROVIDES += "virtual/libintl virtual/libiconv"
inherit autotools texinfo systemd

LEAD_SONAME = "libc.so"

CACHED_CONFIGUREVARS += " \
  ac_cv_path_BASH_SHELL=${base_bindir}/bash \
  libc_cv_slibdir=${base_libdir} \
  libc_cv_rootsbindir=${base_sbindir} \
  libc_cv_localedir=${localedir} \
  libc_cv_ssp_strong=no \
  libc_cv_ssp_all=no \
  libc_cv_ssp=no \
"

GLIBC_EXTRA_OECONF ?= ""
GLIBC_EXTRA_OECONF_class-nativesdk = ""

# glibc uses PARALLELMFLAGS variable to pass parallel build info so transfer
# PARALLEL_MAKE into PARALLELMFLAGS and empty out PARALLEL_MAKE
EGLIBCPARALLELISM := "PARALLELMFLAGS="${PARALLEL_MAKE}""
EXTRA_OEMAKE[vardepsexclude] += "EGLIBCPARALLELISM"
EXTRA_OEMAKE += "${EGLIBCPARALLELISM}"
PARALLEL_MAKE = ""

# glibc make-syscalls.sh has a number of issues with /bin/dash and
# it's output which make calls via the SHELL also has issues, so
# ensure make uses /bin/bash
EXTRA_OEMAKE += "SHELL=/bin/bash"

do_configure_prepend() {
	sed -e "s#@BASH@#/bin/sh#" -i ${S}/elf/ldd.bash.in
}

# Enable backtrace from abort()
do_configure_append_arm () {
	echo "CFLAGS-abort.c = -fasynchronous-unwind-tables" >> ${B}/configparms
	echo "CFLAGS-raise.c = -fasynchronous-unwind-tables" >> ${B}/configparms
}
