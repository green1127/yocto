SUMMARY = "bitbake-layers recipe"
DESCRIPTION = "Recipe created by bitbake-layers"
LICENSE = "GPLv3"
LIC_FILES_CHKSUM = "file://LICENSES/GPL-3.0-or-later.txt;md5=8da5784ab1c72e63ac74971f88658166"

# Refer to: https://bitbucket.org/tobylorenz/vector_blf/issues/17/yocto-rocko-build-errors

# Here are the tags: https://bitbucket.org/tobylorenz/vector_blf/downloads/?tab=tags
SRCREV = "0e44244f0dc8df85c58260227d0649bbf3154f01"

SRC_URI = "https://bitbucket.org/tobylorenz/vector_blf/get/${SRCREV}.tar.gz"
SRC_URI[md5sum] = "413ffb952ba4969d10d4ba429c5e8f4a"
SRC_URI[sha256sum] = "9b019d4b61455b1db173f61156d18ad3f7becebf5d32dce1dd45c0680938876c"

def short_srcrev(d):
    return d.getVar('SRCREV')[:12]

SHORT_SRCREV = "${@short_srcrev(d)}"

DEPENDS = "boost zlib"

S = "${WORKDIR}/tobylorenz-vector_blf-${SHORT_SRCREV}"

PACKAGECONFIG ??= ""
PACKAGECONFIG[run-doxygen] = "-DOPTION_RUN_DOXYGEN=ON,-DOPTION_RUN_DOXYGEN=OFF,doxygen,"

inherit cmake
