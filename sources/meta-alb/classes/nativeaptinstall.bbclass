# The purpose of this class is to simplify the process of installing debian packages
#    to a debian/ubuntu root file system.
# It transparently manages the setup of the pseudo fake root environment and
#    the installation of the packages with all their prerequisites.
# Any additional configuration of the target package management system is also 
#    handled transparently as needed.
#
# Custom shell operations that require chroot can also be executed using this class,
#    by adding them to a function named 'do_aptget_user_update' and defined in the
#    caller recipe, and executing the task do_aptget_update then.
#
# All that is required in order to use this class is:
# - define variables:
#   APTGET_CHROOT_DIR - the full path to the root filesystem where the packages
#                       will be installed
#   APTGET_EXTRA_PACKAGES - the list of debian packages (space separated) to be
#                           installed over the existing root filesystem
#   APTGET_EXTRA_PACKAGES_LAST - the list of debian packages (space separated) to be
#                           installed over the existing root filesystem, after all packages
#                           in APTGET_EXTRA_PACKAGES is installed and all operations in
#                           'do_aptget_userupdate' have been executed.
#							'do_aptget_finaluserupdate' will be executed then.
#   APTGET_EXTRA_SOURCE_PACKAGES - the list of debian source packages (space separated)
#                                  to be installed over the existing root filesystem
#   APTGET_EXTRA_PACKAGES_SERVICES_DISABLED - the list of debian packages (space separated)
#                                  to be installed over the existing root filesystem, which
#                                  must not allow any services to be (re)started. They
#                                  will be installed before packages in APTGET_EXTRA_PACKAGES,
#                                  since most probably they are (unwanted) dependencies
#   APTGET_EXTRA_LIBRARY_PATH - extra paths to search target libraries, separated by ':'
#   APTGET_EXTRA_PPA - extra PPA definitions, using format 'ADDRESS;KEY_SERVER;KEY_HASH[;type[;name]]',
#                      separated by space, where type and name are optional.
#                      'type' can be 'deb' or 'deb-src' (default 'deb')
#                      'name' if specified will be created under '/etc/apt/sources.list.d/';
#                      otherwise the PPA string will be appended to '/etc/apt/sources.list'
#   APTGET_ADD_USERS - users to be added to the file system (space separated), following
#                      format 'name:pass:shell'.
#                      'name' is the user name.
#                      'pass' is an encrypted password (e.g. generated with 
#                          `echo "P4sSw0rD" | openssl passwd -stdin`). If empty or missing, 
#                      they'll get an empty password. If you get 'pass' containing ':'
#                      then generate it again.
#                      'shell' is the default shell (if empty, default is /bin/sh).
#   APTGET_SKIP_UPGRADE - (optional) prevent running apt-get upgrade on the root filesystem
#   APTGET_SKIP_FULLUPGRADE - (optional) prevent running apt-get full-upgrade on the root filesystem
#   APTGET_YOCTO_TRANSLATION - (optional) pairs of <debianpkgname>:<commalistofyoctopkgnames>
#                      to automatically correct dependencies
#   APTGET_INIT_PACKAGES - (optional) For apt to work right on arbitrary setups, some
#                      minimum packages are needed. This is preset appropriately but may be changed.
# - append to function 'do_aptget_user_update' (optional) containing all custom processing that
#          normally require to be executed under chroot (with root privileges)
# - append to function 'do_aptget_user_finalupdate' (optional) containing all custom processing that
#          normally require to be executed under chroot (with root privileges)
# 		   after APTGET_EXTRA_PACKAGES_LAST has been processed.
# - call function 'do_aptget_update' either directly (e.g. call it from 'do_install')
#        or indirectly (e.g. add it to the variable 'ROOTFS_POSTPROCESS_COMMAND')
#
# Prerequisites:
# - The root file system must already be generated under ${APTGET_CHROOT_DIR} (e.g 
#    from a debian/ubuntu CD image or by running debootstrap)
#
# Note: If your host requires a proxy to connect to the internet, then you should use the same
# configuration for the chroot environment where the root filesystem to be updated.
# For this purpose you should set the following variables (preferably in local.conf):
# ENV_HOST_PROXIES - a space separated list of host side temporary proxies, e.g.
#     ENV_HOST_PROXIES = "http_proxy=http://my.proxy.nxp.com:8080 \
#                         https_proxy=http://my.proxy.nxp.com:8080 "
# APTGET_HOST_PROXIES - a space separated list of 'Acquire' options to be written to the apt.conf from
#                       the target root filesystem, which is used during the filesystem update, e.g.:
#     APTGET_HOST_PROXIES = "Acquire::http::proxy \"my.proxy.nxp.com:8080/\"; \
#                            Acquire::http::proxy \"my.proxy.nxp.com:8080/\"; "
# Normally only the http(s) proxy is required (to be added to ENV_HOST_PROXIES). 
# APTGET_HOST_PROXIES, if missing, is generated from the proxy data in ENV_HOST_PROXIES.

APTGET_EXTRA_PACKAGES ?= ""
APTGET_EXTRA_PACKAGES_LAST ?= ""
APTGET_EXTRA_SOURCE_PACKAGES ?= ""
APTGET_EXTRA_PACKAGES_SERVICES_DISABLED ?= ""

# Parent recipes must define the path to the root filesystem to be updated
APTGET_CHROOT_DIR ?= "${D}"

# Set this to anything but 0 to skip performing apt-get upgrade
APTGET_SKIP_UPGRADE ?= "1"

# Set this to anything but 0 to skip performing apt-get full-upgrade
APTGET_SKIP_FULLUPGRADE ?= "1"

# Set this to anything but 0 to skip performing apt-get clean at the end
APTGET_SKIP_CACHECLEAN ?= "0"

# For perfect compatibility, we run in emulation only.
# We can however speed up package installs to some extent
APTGET_USE_NATIVE_DPKG ?= "1"

# Python versions depend on Ubuntu version, but we need one default.
APTGET_PYTHON_VER ?= "3.5"

# Minimum package needs for apt to work right. Nothing else.
APTGET_INIT_FAKETOOLS_PACKAGES ?= "dbus systemd"
APTGET_INIT_PACKAGES ?= "dbus-user-session apt-transport-https ca-certificates software-properties-common apt-utils"

APTGET_REMAINING_FAKETOOLS_PACKAGES ?= "kmod"

APTGET_DL_CACHE ?= "${DL_DIR}/apt-get/${TRANSLATED_TARGET_ARCH}"
APTGET_CACHE_DIR ?= "${APTGET_CHROOT_DIR}/var/cache/apt/archives"

DEPENDS += "qemu-native virtual/${TARGET_PREFIX}binutils rsync-native coreutils-native dpkg-native"

# We need the proper parameter version for the tool
APTGET_TARGET_ARCH="${@d.getVar('TRANSLATED_TARGET_ARCH', True).replace("aarch64", "arm64")}"

# To run native executables required by some installation scripts
PSEUDO_CHROOT_XPREFIX="${STAGING_BINDIR_NATIVE}/qemu-${TRANSLATED_TARGET_ARCH}"
DPKG_NATIVE="${STAGING_BINDIR_NATIVE}/dpkg"

# When running in qemu, we don't really want libpseudo as qemu is already
# running with libpseudo. We want to be as chroot as possible and we
# really only want to run native things inside pseudo chroot
APTGET_EXTRA_LIBRARY_PATH_COLON="${@":".join((d.getVar("APTGET_EXTRA_LIBRARY_PATH") or "").split())}"
QEMU_SET_ENV="PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin,LD_LIBRARY_PATH=${APTGET_EXTRA_LIBRARY_PATH_COLON},PSEUDO_PASSWD=${APTGET_CHROOT_DIR},LC_ALL=C,DEBIAN_FRONTEND=noninteractive"
QEMU_UNSET_ENV="LD_PRELOAD,APT_CONFIG"

# This is an ugly one, but I haven't come up yet with a neat solution.
# It turns out that PAM rejects audit_log_acct_message() because the
# PAM service runs on the host and our pseudo chroot setup does not
# run as real root. So it doesn't matter that our /etc/passwd file
# really is inside the fakeroot because the authentication check is
# done outside. This affects any host with PAM enabled. We also
# can't just grab the library call in pseudo because it actually runs
# inside the qemu environment fully emulated ... where pseudo is not
# applied.
# As quick hack/fix, we just don't do chfn ...
PSEUDO_CHROOT_XTRANSLATION="chfn=/bin/true"

# We force default PATH related elements into chroot as well as
# any full path executables and scripts
PSEUDO_CHROOT_FORCED="\
/usr/local/bin:\
/usr/local/sbin:\
/usr/bin:\
/usr/sbin:\
/bin:\
/sbin:\
/root:\
/*:\
"

# Some things we always want from the host. This is pseudo related
# stuff and also dynamic fs elements.
PSEUDO_CHROOT_EXCEPTIONS="\
${PSEUDO_CHROOT_XPREFIX}:\
${PSEUDO_PREFIX}/*:\
${PSEUDO_LIBDIR}*/*:\
${PSEUDO_LOCALSTATEDIR}*:\
${PSEUDO_LOCALSTATEDIR}:\
/dev/null:\
/dev/zero:\
/dev/random:\
/dev/urandom:\
/dev/tty:\
/dev/pts:\
/dev/pts/*:\
/dev/ptmx:\
${DPKG_NATIVE}:\
/proc/self/fd/*:\
/proc/self/fd:\
/proc/self/maps:\
"

ENV_HOST_PROXIES ?= ""
APTGET_HOST_PROXIES ?= ""
APTGET_EXECUTABLE ?= "/usr/bin/apt-get"
APTGET_DEFAULT_OPTS ?= "-qy -o=Dpkg::Use-Pty=0"

aptget_determine_host_proxies() {
	ENV_HOST_PROXIES="${ENV_HOST_PROXIES}"
	if [ -z "$ENV_HOST_PROXIES" ]; then
		if [ -n "${http_proxy}" ]; then
			ENV_HOST_PROXIES="$ENV_HOST_PROXIES http_proxy=${http_proxy}"
		fi
		if [ -n "${https_proxy}" ]; then
			ENV_HOST_PROXIES="$ENV_HOST_PROXIES https_proxy=${https_proxy}"
		fi
		if [ -n "${ftp_proxy}" ]; then
			ENV_HOST_PROXIES="$ENV_HOST_PROXIES ftp_proxy=${ftp_proxy}"
		fi
	fi
	export ENV_HOST_PROXIES="$ENV_HOST_PROXIES"
}

# We want to ensure that during packaging we use the same
# passwd/group file that we used during build up of the rootfs.
PSEUDO_PASSWD="${APTGET_CHROOT_DIR}:${STAGING_DIR_NATIVE}"

aptget_update_presetvars() {
	# To avoid useless and complicated directory references outside
	# our chroot that just make processing more complex and time
	# consuming, we work in the chroot directory
	cd "${APTGET_CHROOT_DIR}"

	export PSEUDO_PASSWD="${APTGET_CHROOT_DIR}:${STAGING_DIR_NATIVE}"

	# All this depends on the updated pseudo-native with better 
	# chroot support. Without it, apt-get will fail.
	export PSEUDO_CHROOT_XTRANSLATION="${PSEUDO_CHROOT_XTRANSLATION}"
	export PSEUDO_CHROOT_FORCED="${PSEUDO_CHROOT_FORCED}"
	export PSEUDO_CHROOT_EXCEPTIONS="${PSEUDO_CHROOT_EXCEPTIONS}"

	# With this little trick, we can qemu target-side executables
	# inside pseudo chroot without losing pseudo functionality.
	# This is a must have for some of the package related scripts
	# that have to use the target side executables.
	# This depends on both our pseudo and qemu update
	export PSEUDO_CHROOT_XPREFIX="${PSEUDO_CHROOT_XPREFIX}"
	export QEMU_SET_ENV="${QEMU_SET_ENV}"
	export QEMU_UNSET_ENV="${QEMU_UNSET_ENV}"
	export QEMU_LIBCSYSCALL="1"
	#unset QEMU_LD_PREFIX

	# Add any proxies from the host, according to
	# https://wiki.yoctoproject.org/wiki/Working_Behind_a_Network_Proxy
        # Note that we split environment setup and rootfs setup!
        # Rootfs proxy setup is only done once in aptget_setup_proxies
        # Environment setup needs to be done every time in
        # aptget_update_presetvars

	aptget_determine_host_proxies
	while [ -n "$ENV_HOST_PROXIES" ]; do
		IFS=" " read -r proxy_line ENV_HOST_PROXIES <<END_PROXY
$ENV_HOST_PROXIES
END_PROXY
		IFS="=" read -r proxy_name proxy_val <<END_PROXY
$proxy_line
END_PROXY
		IFS="_" read -r proxy_type proxy_string <<END_PROXY
$proxy_name
END_PROXY
		if [ "$proxy_string" != "proxy" ]; then
			# We already warn when setting up the rootfs
                        #bbwarn "Invalid proxy \"$proxy\""
			continue
		fi

		export QEMU_SET_ENV="$QEMU_SET_ENV,${proxy_type}_${proxy_string}=$proxy_val"
	done

}

fakeroot aptget_setup_proxies() {
	# Add any proxies from the host, according to
	# https://wiki.yoctoproject.org/wiki/Working_Behind_a_Network_Proxy
        # Note that we split environment setup and rootfs setup!
        # Rootfs proxy setup is only done once in aptget_setup_proxies
        # Environment setup needs to be done every time in
        # aptget_update_presetvars

	# apt may not be fully configured at this stage
        mkdir -p "${APTGET_CHROOT_DIR}/etc/apt/apt.conf.d"

        # We use the faketool mechanism to install our proxies in a
        # reversible way
        xf="/__etc_apt_apt.conf.d_01yoctoinstallproxies__"
        rm -f "${APTGET_CHROOT_DIR}$xf"

	aptget_determine_host_proxies
	while [ -n "$ENV_HOST_PROXIES" ]; do
		IFS=" " read -r proxy_line ENV_HOST_PROXIES <<END_PROXY
$ENV_HOST_PROXIES
END_PROXY
		IFS="=" read -r proxy_name proxy_val <<END_PROXY
$proxy_line
END_PROXY
		IFS="_" read -r proxy_type proxy_string <<END_PROXY
$proxy_name
END_PROXY
		if [ "$proxy_string" != "proxy" ]; then
			bbwarn "Invalid proxy \"$proxy\""
			continue
		fi

		# If APTGET_HOST_PROXIES is not defined in local.conf, then
		# apt.conf is populated using proxy information in ENV_HOST_PROXIES
		if [ -z "${APTGET_HOST_PROXIES}" ]; then
			echo >>"${APTGET_CHROOT_DIR}$xf" "Acquire::$proxy_type::proxy \"$proxy_val/\"; /* Yocto */"
		fi
	done

	APTGET_HOST_PROXIES="${APTGET_HOST_PROXIES}"
	while [ -n "$APTGET_HOST_PROXIES" ]; do
		read -r proxy <<END_PROXY
$APTGET_HOST_PROXIES
END_PROXY
		echo >>"${APTGET_CHROOT_DIR}$xf" "$proxy"
	done

        if [ -e "${APTGET_CHROOT_DIR}$xf" ]; then
                aptget_always_install_faketool "/etc/apt/apt.conf.d/01yoctoinstallproxies" $xf
        fi
}

fakeroot aptget_preserve_file() {
        if [ -e "${APTGET_CHROOT_DIR}$1" ] || [ -L "${APTGET_CHROOT_DIR}$1" ]; then
                mv -f "${APTGET_CHROOT_DIR}$1" "${APTGET_CHROOT_DIR}$1.yocto"
                return
        fi
        false
}

aptget_file_is_preserved() {
        test -e "${APTGET_CHROOT_DIR}$1.yocto" || test -L "${APTGET_CHROOT_DIR}$1.yocto"
}

fakeroot aptget_restore_file() {
        if aptget_file_is_preserved "$1"; then
                mv -f "${APTGET_CHROOT_DIR}$1.yocto" "${APTGET_CHROOT_DIR}$1"
        fi
}

aptget_link_is_pointing_to() {
        test -L "${APTGET_CHROOT_DIR}$1" && test "`readlink ${APTGET_CHROOT_DIR}$1`" = "$2"
}

fakeroot aptget_delete_fakeproc() {
        # Obviously we can't have a /proc/1 in an offline rootfs.
        # So we remove our temporary helper again
        rm -f "${APTGET_CHROOT_DIR}/proc/self"
        rm -fr "${APTGET_CHROOT_DIR}/proc/1"
}

fakeroot aptget_install_fakeproc() {
        # This is magic to fool package installations into thinking
        # good things about our rootfs and our runtime environment
        mkdir -p "${APTGET_CHROOT_DIR}/proc/1"
        ln -s "/" "${APTGET_CHROOT_DIR}/proc/1/root"
        ln -s "1" "${APTGET_CHROOT_DIR}/proc/self"
}

fakeroot aptget_delete_faketool() {
        if aptget_link_is_pointing_to $1 $2; then
                aptget_restore_file $1
        fi
        rm -f "${APTGET_CHROOT_DIR}$2"
}

fakeroot aptget_always_install_faketool() {
        if ! aptget_link_is_pointing_to $1 $2; then
                aptget_preserve_file $1 || true
                ln -s "$2" "${APTGET_CHROOT_DIR}$1"
        fi
}

fakeroot aptget_install_faketool() {
        if ! aptget_link_is_pointing_to $1 $2; then
                if aptget_preserve_file $1; then
                        ln -s "$2" "${APTGET_CHROOT_DIR}$1"
                fi
        fi
}

fakeroot aptget_delete_faketools() {
        aptget_delete_faketool "/bin/lsmod"         "/__fake_lsmod__"
        xt="/bin/udevadm"
        if ! aptget_file_is_preserved $xt; then
                xt="/sbin/udevadm"
        fi
        aptget_delete_faketool $xt                  "/__fake_udevadm__"
        aptget_delete_faketool "/bin/mountpoint"    "/__fake_mountpoint__"
        aptget_delete_faketool "/usr/bin/systemctl" "/__fake_systemctl__"
        aptget_delete_faketool "/usr/bin/dbus-send" "/__fake_dbus-send__"
        aptget_delete_faketool "/usr/bin/dpkg"      "/__dpkgwrapper__"
}

fakeroot aptget_install_faketools() {
        # Very ugly workaround. Turns out that some packages use
        # lsmod, e.g., console-setup. lsmod wants to access the
        # module database via sysfs. We are not in a live system,
        # so sysfs does not exist, which leads to errors. These
        # errors then make an otherwise perfectly valid install
        # fail. Our workaround is to temporarily replace lsmod.
        # This is ok as we don't have any modules loaded anyway.
        xf="/__fake_lsmod__"
        if [ ! -e "${APTGET_CHROOT_DIR}$xf" ]; then
                cat << EOF >${APTGET_CHROOT_DIR}$xf
#!/bin/sh
echo 'Module                  Size  Used by'
EOF
                chmod a+x "${APTGET_CHROOT_DIR}$xf"
        fi
        aptget_install_faketool "/bin/lsmod"            $xf

        # Turns out that a good number of package installs trigger
        # udevadm. In the past this was benign and ignored in chroot
        # environments. This is currently not the case for Ubuntu 20
        # So we install a fake udevadm temporarily to work around the
        # problem which in fact simplifies installs for all versions.
        xf="/__fake_udevadm__"
        if [ ! -e "${APTGET_CHROOT_DIR}$xf" ]; then
cat << EOF >${APTGET_CHROOT_DIR}$xf
#!/bin/sh
case \$1 in
        trigger|control|settle|monitor)
                echo "udevadm command \$1 ignored"
                exit 0
                ;;
esac
udevadm.yocto "\$@"
EOF
                chmod a+x "${APTGET_CHROOT_DIR}$xf"
        fi
        xt="/bin/udevadm"
        if [ ! -e "${APTGET_CHROOT_DIR}$xt" ]; then
                xt="/sbin/udevadm"
        fi
        aptget_install_faketool $xt                     $xf

        # Packages like Java use "mountpoint" to check if "/proc" is
        # real. For us, it isn't real, so we need to fake things
        xf="/__fake_mountpoint__"
        if [ ! -e "${APTGET_CHROOT_DIR}$xf" ]; then
                cat << EOF >${APTGET_CHROOT_DIR}$xf
#!/bin/sh
for i in \$@; do
        case \$i in
                -*)
                        # Skip
                        ;;
                /proc)
                        echo "Pretending that /proc is a mountpoint"
                        exit 0
                        ;;
        esac
done
mountpoint.yocto "\$@"
EOF
                chmod a+x "${APTGET_CHROOT_DIR}$xf"
        fi
        aptget_install_faketool "/bin/mountpoint"       $xf

        # Reloading system daemons causes log issues, so we want to
        # avoid that. We can't reload anything offline anyway.
        xf="/__fake_systemctl__"
        if [ ! -e "${APTGET_CHROOT_DIR}$xf" ]; then
                cat << EOF >${APTGET_CHROOT_DIR}$xf
#!/bin/sh
# Hack! If invoked without parameters, we
# assume is was invoked via a "runlevel" symlink
# Unfortunately there doesn't seem to be a way
# to determine the symlink name that invokes a
# script
args="runlevel"
if [ \$# -ne 0 ]; then
        args="\$@"
fi
for i in \$args; do
        case \$i in
                runlevel)
                        echo "N 1"
                        exit 0
                        ;;
                list-units)
                        echo "UNIT          LOAD   ACTIVE SUB    DESCRIPTION"
                        echo "rescue.target loaded active active Yocto Installation"
                        exit 0
                        ;;
                is-active|is-failed)
                        # Nothing is active or failed!
                        exit 1
                        ;;
                daemon-reload|daemon-reexec|reload|restart)
                        exit 0
                        ;;
                list-sockets|list-timers|status|list-machines)
                        # Silent ok
                        exit 0
                        ;;
        esac
done
echo "Invoking: systemctl.yocto \$@"
systemctl.yocto "\$@"
EOF
                chmod a+x "${APTGET_CHROOT_DIR}$xf"
        fi
        aptget_install_faketool "/usr/bin/systemctl"    $xf

        # dbus-send is another on of those that do not make sense
        # offline
        xf="/__fake_dbus-send__"
        if [ ! -e "${APTGET_CHROOT_DIR}$xf" ]; then
                cat << EOF >${APTGET_CHROOT_DIR}$xf
#!/bin/sh
exit 20
EOF
                chmod a+x "${APTGET_CHROOT_DIR}$xf"
        fi
        aptget_install_faketool "/usr/bin/dbus-send"    $xf

	if [ "${APTGET_USE_NATIVE_DPKG}" != "0" ]; then
                # We can speed up specfic operations.
                xf="/__dpkgwrapper__"
                cat << EOF >${APTGET_CHROOT_DIR}$xf
#!/bin/sh
for i in \$@; do
        case \$i in
                --)
                        break
                        ;;
                --unpack)
                        ${DPKG_NATIVE} --admindir=/var/lib/dpkg --instdir=/  "\$@"
                        exit
                        ;;
        esac
done
dpkg.yocto "\$@"
EOF
                chmod a+x "${APTGET_CHROOT_DIR}$xf"


                aptget_install_faketool "/usr/bin/dpkg" $xf
        fi
}

fakeroot aptget_run_aptget() {
        xd=`date -R`
        bbnote "${xd}: ${APTGET_EXECUTABLE} ${APTGET_DEFAULT_OPTS} $@"
        aptget_install_faketools

        # We operate in our fake root dir, but we need to ensure we
        # override PWD or the emulated code will see a path outside
        export PWD="/"
        test $aptgetfailure -ne 0 || chroot "${APTGET_CHROOT_DIR}" ${APTGET_EXECUTABLE} ${APTGET_DEFAULT_OPTS} "$@" || aptgetfailure=1

        aptget_delete_faketools
}

fakeroot aptget_populate_cache_from_sstate() {
	if [ -e "${APTGET_CACHE_DIR}" ]; then
		mkdir -p "${APTGET_DL_CACHE}"
		chroot "${APTGET_CHROOT_DIR}" ${APTGET_EXECUTABLE} ${APTGET_DEFAULT_OPTS} check
		rsync -d -u -t --include *.deb "${APTGET_DL_CACHE}/" "${APTGET_CACHE_DIR}"
		chroot "${APTGET_CHROOT_DIR}" ${APTGET_EXECUTABLE} ${APTGET_DEFAULT_OPTS} check
	fi
}

fakeroot aptget_save_cache_into_sstate() {
	if [ -e "${APTGET_CACHE_DIR}" ]; then
		mkdir -p "${APTGET_DL_CACHE}"
		chroot "${APTGET_CHROOT_DIR}" ${APTGET_EXECUTABLE} ${APTGET_DEFAULT_OPTS} check
		rsync -d -u -t --include *.deb "${APTGET_CACHE_DIR}/" "${APTGET_DL_CACHE}"
	fi
}

fakeroot aptget_update_begin() {
	# Once the basic rootfs is unpacked, we use the local passwd
	# information.
	aptget_update_presetvars;

	aptgetfailure=0
	# While we do our installation stunt in qemu land, we also want
	# to be able to use host side networking configs. This means we
	# need to protect the host and DNS config. We do a bit of a
	# convoluted stunt here to hopefully be flexible enough about
	# different rootfs types.
	cp "/etc/hosts" "${APTGET_CHROOT_DIR}/__etchosts__"
        aptget_install_faketool "/etc/hosts" "/__etchosts__"
	cp "/etc/resolv.conf" "${APTGET_CHROOT_DIR}/__etcresolvconf__"
        aptget_install_faketool "/etc/resolv.conf" "/__etcresolvconf__"

	# We need to set at least one (dummy) user and we set passwords for all of them.
	# useradd is not debian, but good enough for now.
	# Technically, this should be done at image generation time,
	# but the default Yocto mechanisms are a bit intrusive.
	# This needs some research. UNDERSTAND AND FIX!
	# In any case, this needs to run as chroot so that we modify
	# the proper passwd/group inside pseudo.
	# The Ubuntu 'adduser' doesn't work because passwd is called
	# which doesn't like our pseudo root
	if [ -n "${APTGET_ADD_USERS}" ]; then
		# Tricky variable hack to get word parsing for Yocto
		# variables in the shell.
		x="${APTGET_ADD_USERS}"
		for user in $x; do

			IFS=':' read -r user_name user_passwd user_shell <<END_USER
$user
END_USER

			if [ -z "$user_name" ]; then
				bbwarn "Empty user name, skipping."
				continue
			fi
			if [ -z "$user_passwd" ]; then
				# encrypted empty password
				user_passwd="BB.jlCwQFvebE"
			fi

			user_shell_opt=""
			if [ -n "$user_shell" ]; then
				user_shell_opt="-s $user_shell"
			fi

			if [ -z "`cat ${APTGET_CHROOT_DIR}/etc/passwd | grep $user_name`" ]; then
				chroot "${APTGET_CHROOT_DIR}" /usr/sbin/useradd -p "$user_passwd" -U -G sudo,users -m "$user_name" $user_shell_opt
			fi

		done
	fi

        # This is magic to fool package installations into thinking
        # good things about our rootfs
        aptget_install_fakeproc

	# Yocto environment. If we kept apt packages privately from
	# a prior run, prepopulate the package cache locally to avoid
	# costly downloads
	aptget_populate_cache_from_sstate

        # From this point on, we may need network access
        aptget_setup_proxies

	if [ "${APTGET_USE_NATIVE_DPKG}" != "0" ]; then
                # We need to establish the proper architecture globally, so
                # that we do not pick it up from dpkg. We may use a native
                # dpkg for some things, so we do not want to run into issues
                # as dpkg-native defaults to host architecture.
                mkdir -p "${APTGET_CHROOT_DIR}/etc/apt/apt.conf.d"
                chroot "${APTGET_CHROOT_DIR}" /usr/bin/dpkg --add-architecture ${APTGET_TARGET_ARCH}
                echo >"${APTGET_CHROOT_DIR}/etc/apt/apt.conf.d/01yoctoinstallarchitecture" "APT::Architecture \"${APTGET_TARGET_ARCH}\";"
        fi

	# Before we can play with the package manager in any
	# meaningful way, we need to sync the database.
	if [ -n "${APTGET_EXTRA_SOURCE_PACKAGES}" ]; then
		if grep '# deb-src' ${APTGET_CHROOT_DIR}/etc/apt/sources.list; then
			chroot "${APTGET_CHROOT_DIR}" /bin/sed -i 's/# deb-src/deb-src/g' /etc/apt/sources.list
		fi
	fi

	# Prepare apt to be generically usable
	chroot "${APTGET_CHROOT_DIR}" ${APTGET_EXECUTABLE} ${APTGET_DEFAULT_OPTS} update

        # See that everything is downloaded first. This is an
        # optimization which will help to avoid failures late in the
        # game due to bad intenet connections and helps the user.
        # It means that no matter what else might happen, the package
        # cache should be properly populated then for reruns.
        # Given how we do the PPA setup, we have to work this in two
        # stages though and can't download everything right away.
        aptget_run_aptget -d install ${APTGET_INIT_FAKETOOLS_PACKAGES} ${APTGET_INIT_PACKAGES}

	if [ -n "${APTGET_INIT_FAKETOOLS_PACKAGES}" ]; then
                # Packages used by faketools are installed
                # individually so that faketools are used at the right
                # times
		x="${APTGET_INIT_FAKETOOLS_PACKAGES}"
		for i in $x; do
                        aptget_run_aptget install $i
                done
	fi
	if [ -n "${APTGET_INIT_PACKAGES}" ]; then
                aptget_run_aptget install ${APTGET_INIT_PACKAGES}
	fi

	if [ -n "${APTGET_EXTRA_PPA}" ]; then
		DISTRO_NAME=`grep "DISTRIB_CODENAME=" "${APTGET_CHROOT_DIR}/etc/lsb-release" | sed "s/DISTRIB_CODENAME=//g"`
		DISTRO_RELEASE=`grep "DISTRIB_RELEASE=" "${APTGET_CHROOT_DIR}/etc/lsb-release" | sed "s/DISTRIB_RELEASE=//g"`

		if [ -z "$DISTRO_NAME" ]; then 
			bberror "Unable to get target linux distribution codename. Please check that \"${APTGET_CHROOT_DIR}/etc/lsb-release\" is not corrupted."
		fi

		# For apt-key to be reliable, we need both gpg and dirmngr
		# As workaround for an 18.04 gpg regressions, we also use curl
                # In fact, for now we use it generally, because gpg can't
                # talk to dirmngr properly in the emulated environment.
                # This needs to be debugged (FIX!), but the curl method
                # works, too.
		APTGET_GPG_BROKEN="1"
		if [ "$DISTRO_RELEASE" = "18.04" ]; then
			APTGET_GPG_BROKEN="1"
		fi
		if [ -n "$APTGET_GPG_BROKEN" ]; then
			x="gnupg curl"
		else
			x="gnupg dirmngr"
		fi
                aptget_run_aptget install $x

		# Tricky variable hack to get word parsing for Yocto
		# variables in the shell.
		x="${APTGET_EXTRA_PPA}"
		for ppa in $x; do
			IFS=';' read -r ppa_addr ppa_server ppa_hash ppa_type ppa_file_orig <<END_PPA
$ppa
END_PPA

			if [ "`echo $ppa_addr | head -c 4`" = "ppa:" ]; then
				chroot "${APTGET_CHROOT_DIR}" /usr/bin/add-apt-repository -y -s $ppa_addr
				continue;
			fi

			if [ -z "$ppa_type" ]; then
				ppa_type="deb"
			fi
			if [ -n "$ppa_file_orig" ]; then
				ppa_file="/etc/apt/sources.list.d/$ppa_file_orig"
			else
				ppa_file="/etc/apt/sources.list"
			fi
			ppa_proxy=""
			if [ -n "$ENV_HTTP_PROXY" ]; then
				if [ -n "$APTGET_GPG_BROKEN" ]; then
					ppa_proxy="-proxy=$ENV_HTTP_PROXY"
				else
					ppa_proxy="--keyserver-options http-proxy=$ENV_HTTP_PROXY"
				fi
			fi

			echo >>"${APTGET_CHROOT_DIR}/$ppa_file" "$ppa_type $ppa_addr $DISTRO_NAME main"
			if [ -n "$APTGET_GPG_BROKEN" ]; then
				HTTPPPASERVER=`echo $ppa_server | sed "s/hkp:/http:/g"`
				mkdir -p "${APTGET_CHROOT_DIR}/tmp/gpg"
                                mkdir -p "${APTGET_CHROOT_DIR}/etc/apt/trusted.gpg.d/"
				chmod 0600 "${APTGET_CHROOT_DIR}/tmp/gpg"
				chroot "${APTGET_CHROOT_DIR}" /usr/bin/curl -sL "$HTTPPPASERVER/pks/lookup?op=get&search=0x$ppa_hash" | chroot "${APTGET_CHROOT_DIR}" /usr/bin/gpg --homedir /tmp/gpg --import || true
				chroot "${APTGET_CHROOT_DIR}" /usr/bin/gpg --homedir /tmp/gpg --export $ppa_hash > "${APTGET_CHROOT_DIR}/etc/apt/trusted.gpg.d/$ppa_file_orig.gpg"
				rm -rf "${APTGET_CHROOT_DIR}/tmp/gpg"
			else
				chroot "${APTGET_CHROOT_DIR}" /usr/bin/apt-key adv --keyserver $ppa_server $ppa_proxy --recv-key $ppa_hash
			fi
		done
                chroot "${APTGET_CHROOT_DIR}" ${APTGET_EXECUTABLE} ${APTGET_DEFAULT_OPTS} update
	fi

        # After the PPA has been set up, download everything else.
        aptget_run_aptget -d install ${APTGET_REMAINING_FAKETOOLS_PACKAGES} \
                        ${APTGET_EXTRA_PACKAGES_SERVICES_DISABLED} \
                        ${APTGET_EXTRA_PACKAGES} \
                        ${APTGET_EXTRA_SOURCE_PACKAGES} \
                        ${APTGET_EXTRA_PACKAGES_LAST}

        # Packages affected by faketools are installed
        # individually so that faketools are used at the right
        # times
        x="${APTGET_REMAINING_FAKETOOLS_PACKAGES}"
        for i in $x; do
                aptget_run_aptget install $i
        done

	if [ "${APTGET_SKIP_UPGRADE}" = "0" ]; then
		aptget_run_aptget -f install
		aptget_run_aptget upgrade
	fi

	if [ "${APTGET_SKIP_FULLUPGRADE}" = "0" ]; then
                aptget_run_aptget -f install
		aptget_run_aptget full-upgrade
	fi

	if [ -n "${APTGET_EXTRA_PACKAGES_SERVICES_DISABLED}" ]; then
		# workaround - deny (re)starting of services, for selected packages, since
		# they will make the installation fail
                echo  >"${APTGET_CHROOT_DIR}/__usrsbinpolicy-rc.d__" "#!/bin/sh"
                echo >>"${APTGET_CHROOT_DIR}/__usrsbinpolicy-rc.d__" "exit 101"
                chmod a+x "${APTGET_CHROOT_DIR}/__usrsbinpolicy-rc.d__"
                aptget_always_install_faketool "/usr/sbin/policy-rc.d" "/__usrsbinpolicy-rc.d__"

		aptget_run_aptget install ${APTGET_EXTRA_PACKAGES_SERVICES_DISABLED}

		# remove the workaround
                aptget_delete_faketool "/usr/sbin/policy-rc.d" "/__usrsbinpolicy-rc.d__"
	fi

	if [ -n "${APTGET_EXTRA_PACKAGES}" ]; then
                aptget_run_aptget install ${APTGET_EXTRA_PACKAGES}
	fi

	if [ -n "${APTGET_EXTRA_SOURCE_PACKAGES}" ]; then
		# We need this to get source package handling properly
		# configured for a subsequent apt-get source
		aptget_run_aptget install dpkg-dev

		# For lack of a better idea, we install source packages
		# into the root user's home. if we could guarantee that
		# they are all read only, /opt might be a good place.
		# But we can't guarantee that.
		# Net result is that we use an ugly hack to overcome
		# the chroot directory problem.
		echo  >"${APTGET_CHROOT_DIR}/aptgetsource.sh" "#!/bin/sh"
		echo >>"${APTGET_CHROOT_DIR}/aptgetsource.sh" "cd \$1"
		echo >>"${APTGET_CHROOT_DIR}/aptgetsource.sh" "${APTGET_EXECUTABLE} ${APTGET_DEFAULT_OPTS} source \$2"
		x="${APTGET_EXTRA_SOURCE_PACKAGES}"
		for i in $x; do
			test $aptgetfailure -ne 0 || chroot "${APTGET_CHROOT_DIR}" /bin/bash /aptgetsource.sh "/root" "${i}" || aptgetfailure=1
		done
		rm -f "${APTGET_CHROOT_DIR}/aptgetsource.sh"
	fi

	# Once we have done the installation, save off the package
	# cache locally for repeated use of recipe building
	# We also try to save the cache in case of package install errors
	# to avoid downloads on a subsequent attempt
	aptget_save_cache_into_sstate

	if [ $aptgetfailure -ne 0 ]; then
		bberror "${APTGET_EXECUTABLE} failed to execute as expected!"
		return $aptgetfailure
	fi

	# The list of installed packages goes into the log
	echo "Installed packages:"
	chroot "${APTGET_CHROOT_DIR}" /usr/bin/dpkg -l | grep '^ii' | awk '{print $2}'
}

# Must have to preset all variables properly. It also means that
# the user of this class should not prepend to avoid ordering issues.
fakeroot do_aptget_user_update_prepend() {

	aptget_update_presetvars;
}

# empty placeholder, override it in parent script for more functionality
fakeroot do_aptget_user_update() {

	:
}

# Must have to preset all variables properly. It also means that
# the user of this class should not prepend to avoid ordering issues.
fakeroot do_aptget_user_finalupdate_prepend() {

	aptget_update_presetvars;
}

# empty placeholder, override it in parent script for more functionality
fakeroot do_aptget_user_finalupdate() {

	:
}

fakeroot aptget_update_extrapackageslast() {

	aptget_update_presetvars;

	aptgetfailure=0
	if [ -n "${APTGET_EXTRA_PACKAGES_LAST}" ]; then
		aptget_run_aptget install ${APTGET_EXTRA_PACKAGES_LAST}
	fi

	if [ $aptgetfailure -ne 0 ]; then
		bberror "${APTGET_EXECUTABLE} failed to execute as expected!"
		return $aptgetfailure
	fi
}

fakeroot aptget_update_end() {

	aptget_update_presetvars;

	aptgetfailure=0
	# Once we have done the installation, save off the package
	# cache locally for repeated use of recipe building
	aptget_save_cache_into_sstate

	if [ "${APTGET_SKIP_CACHECLEAN}" = "0" ]; then
		aptget_run_aptget clean
	fi

        # Remove any proxy instrumentation
        xf="/__etc_apt_apt.conf.d_01yoctoinstallproxies__"
        aptget_delete_faketool "/etc/apt/apt.conf.d/01yoctoinstallproxies" $xf

        # Remove our temporary helper again
        aptget_delete_fakeproc

	# Now that we are done in qemu land, we reinstate the original
	# networking config of our target rootfs.
        aptget_delete_faketool "/etc/hosts" "/__etchosts__"
        aptget_delete_faketool "/etc/resolv.conf" "/__etcresolvconf__"
}

python do_aptget_update() {
    bb.build.exec_func("aptget_update_begin", d);
    bb.build.exec_func("do_aptget_user_update", d);
    bb.build.exec_func("aptget_update_extrapackageslast", d);
    bb.build.exec_func("do_aptget_user_finalupdate", d);
    bb.build.exec_func("aptget_update_end", d);
}

# We don't want to simply use the image.bbclass invocation of systemctl
# because that setup may be not quite compatible to our target rootfs.
# So if the target rootfs provides systemctl, we use the target rootfs
# version instead for better compatibility. Using the native one may
# just lead to failure on a complex rootfs that relies on full
# functionality (as is happening for Ubuntu 20 in a complex image setup 
# with sshd.service). The Yocto systemctl is not the real thing.
# The solution is to do the equivalent of
# image.bbclass/systemd_preset_all when finishing up the Ubuntu install,
# but in the Ubuntu rootfs chroot context with the proper variable setup.
# We still provide the fallback to have classic behavior in the unlikely
# case of a weird target rootfs without systemctl.
IMAGE_FEATURES_append = " stateless-rootfs"
fakeroot do_aptget_user_finalupdate_append() {
	# This code is only executed when an image is built so that it
	# does not affect non-image package generation.
	if [ -n "${IMGDEPLOYDIR}" ]; then
		if [ -e "${APTGET_CHROOT_DIR}${root_prefix}/lib/systemd/systemd" ]; then
			bbnote "Presetting systemd services via systemctl..."
			if [ -e "${APTGET_CHROOT_DIR}${root_prefix}/bin/systemctl" ]; then
				chroot "${APTGET_CHROOT_DIR}" ${root_prefix}/bin/systemctl --root=/ --preset-mode=enable-only preset-all
			else
				# Fall back to the image.bbclass systemd_preset_all method
				# using the fake systemctl script
				systemctl --root="${APTGET_CHROOT_DIR}" --preset-mode=enable-only preset-all
			fi
			bbnote "Done presetting systemd services via systemctl"
		fi
	fi
}

# This function is a "safe" trick to run something once on startup
# in a systemd environment.
# aptget_install_oneshot_service <name> <description> <command>
# aptget_install_oneshot_service "makescripts" "Build kernel scripts" "/usr/bin/make V=1 -C /usr/src/kernel scripts"
fakeroot aptget_install_oneshot_service() {
	cat >"${APTGET_CHROOT_DIR}${root_prefix}/lib/systemd/system/nxpyocto_$1.service" <<EOF
[Unit]
Description=NXP Yocto: $2

[Service]
Type=oneshot
ExecStart=$3
ExecStartPost=${root_prefix}/bin/systemctl disable %n

[Install]
WantedBy=default.target
EOF
	chmod 0644 "${APTGET_CHROOT_DIR}${root_prefix}/lib/systemd/system/nxpyocto_$1.service"
	chroot "${APTGET_CHROOT_DIR}" ${root_prefix}/bin/systemctl enable nxpyocto_$1.service
}

# The various apt packages need to be translated properly into Yocto
# RPROVIDES_${PN}
APTGET_ALL_PACKAGES = "\
        ${APTGET_INIT_PACKAGES} \
        ${APTGET_EXTRA_PACKAGES} \
	${APTGET_EXTRA_PACKAGES_LAST} \
	${APTGET_EXTRA_SOURCE_PACKAGES} \
	${APTGET_EXTRA_PACKAGES_SERVICES_DISABLED} \
	${APTGET_RPROVIDES} \
"

# We have some preconceived notions in APTGET_YOCTO_TRANSLATION about
# the Yocto names we find in the current layer set. If the translation
# does not match the actual packages, you can get rather weird dependency
# resolutions that mess up the final result. Rather than silently
# messing things up, we will hardcode our compatibility here and
# complain if needed!
python() {
        lc = d.getVar("LAYERSERIES_CORENAMES")
        if ("zeus" not in lc) and ("dunfell" not in lc) and ("gatesgarth" not in lc):
                bb.error("nativeaptinstall.bbclass is incompatible to the current layer set")
                bb.error("You must check APTGET_YOCTO_TRANSLATION and update the anonymous python() function!")
}
# Now we translate the various debian package names into Yocto names
# to be able to set up RPROVIDERS and the like properly. The list
# below is not exhaustive but covers the currently known use cases.
# If suddenly Yocto packages show up in the image when Ubuntu already
# provides the solution, the likelihood is high that a name translation
# may be missing.
APTGET_YOCTO_TRANSLATION += "\
    libdb5.3:db \
    device-tree-compiler:dtc \
    libffi6:libffi7 \
    libnss-db:libnss-db2 \
    libpam0g:libpam \
    libssl1.0.0:libssl1.0 \
    libssl1.1:libssl1.1 \
    libssl-dev:openssl-dev,openssl-qoriq-dev \
    openssl:openssl-bin,openssl-qoriq-bin,openssl-conf,openssl-qoriq-conf,openssl-misc,openssl-qoriq-misc \
    python${APTGET_PYTHON_VER}:python3 \
    xz-utils:xz \
    zlib1g:libz1 \
    ncurses-base:ncurses-terminfo-base \
    libmpc3:libmpc \
"
# This is a really ugly one for us because Yocto does a very fine
# grained split of libc. Note how we avoid spaces in the wrong places!
APTGET_YOCTO_TRANSLATION += "\
	libc6:libc6,libc6-utils,glibc,eglibc\
glibc-thread-db,eglibc-thread-db,\
glibc-extra-nss,eglibc-extra-nss,\
glibc-pcprofile,eglibc-pcprofile,\
libsotruss,libcidn,libmemusage,libsegfault,\
glibc-gconv-ansi-x3.110,glibc-gconv-armscii-8,glibc-gconv-asmo-449,\
glibc-gconv-big5hkscs,glibc-gconv-big5,glibc-gconv-brf,\
glibc-gconv-cp10007,glibc-gconv-cp1125,glibc-gconv-cp1250,\
glibc-gconv-cp1251,glibc-gconv-cp1252,glibc-gconv-cp1253,\
glibc-gconv-cp1254,glibc-gconv-cp1255,glibc-gconv-cp1256,\
glibc-gconv-cp1257,glibc-gconv-cp1258,glibc-gconv-cp737,\
glibc-gconv-cp770,glibc-gconv-cp771,glibc-gconv-cp772,\
glibc-gconv-cp773,glibc-gconv-cp774,glibc-gconv-cp775,\
glibc-gconv-cp932,glibc-gconv-csn-369103,glibc-gconv-cwi,\
glibc-gconv-dec-mcs,glibc-gconv-ebcdic-at-de-a,\
glibc-gconv-ebcdic-at-de,glibc-gconv-ebcdic-ca-fr,\
glibc-gconv-ebcdic-dk-no-a,glibc-gconv-ebcdic-dk-no,\
glibc-gconv-ebcdic-es-a,glibc-gconv-ebcdic-es,\
glibc-gconv-ebcdic-es-s,glibc-gconv-ebcdic-fi-se-a,\
glibc-gconv-ebcdic-fi-se,glibc-gconv-ebcdic-fr,\
glibc-gconv-ebcdic-is-friss,glibc-gconv-ebcdic-it,\
glibc-gconv-ebcdic-pt,glibc-gconv-ebcdic-uk,glibc-gconv-ebcdic-us,\
glibc-gconv-ecma-cyrillic,glibc-gconv-euc-cn,\
glibc-gconv-euc-jisx0213,glibc-gconv-euc-jp-ms,glibc-gconv-euc-jp,\
glibc-gconv-euc-kr,glibc-gconv-euc-tw,glibc-gconv-gb18030,\
glibc-gconv-gbbig5,glibc-gconv-gbgbk,glibc-gconv-gbk,\
glibc-gconv-georgian-academy,glibc-gconv-georgian-ps,\
glibc-gconv-gost-19768-74,glibc-gconv-greek7-old,glibc-gconv-greek7,\
glibc-gconv-greek-ccitt,glibc-gconv-hp-greek8,glibc-gconv-hp-roman8,\
glibc-gconv-hp-roman9,glibc-gconv-hp-thai8,glibc-gconv-hp-turkish8,\
glibc-gconv-ibm037,glibc-gconv-ibm038,glibc-gconv-ibm1004,\
glibc-gconv-ibm1008-420,glibc-gconv-ibm1008,glibc-gconv-ibm1025,\
glibc-gconv-ibm1026,glibc-gconv-ibm1046,glibc-gconv-ibm1047,\
glibc-gconv-ibm1097,glibc-gconv-ibm1112,glibc-gconv-ibm1122,\
glibc-gconv-ibm1123,glibc-gconv-ibm1124,glibc-gconv-ibm1129,\
glibc-gconv-ibm1130,glibc-gconv-ibm1132,glibc-gconv-ibm1133,\
glibc-gconv-ibm1137,glibc-gconv-ibm1140,glibc-gconv-ibm1141,\
glibc-gconv-ibm1142,glibc-gconv-ibm1143,glibc-gconv-ibm1144,\
glibc-gconv-ibm1145,glibc-gconv-ibm1146,glibc-gconv-ibm1147,\
glibc-gconv-ibm1148,glibc-gconv-ibm1149,glibc-gconv-ibm1153,\
glibc-gconv-ibm1154,glibc-gconv-ibm1155,glibc-gconv-ibm1156,\
glibc-gconv-ibm1157,glibc-gconv-ibm1158,glibc-gconv-ibm1160,\
glibc-gconv-ibm1161,glibc-gconv-ibm1162,glibc-gconv-ibm1163,\
glibc-gconv-ibm1164,glibc-gconv-ibm1166,glibc-gconv-ibm1167,\
glibc-gconv-ibm12712,glibc-gconv-ibm1364,glibc-gconv-ibm1371,\
glibc-gconv-ibm1388,glibc-gconv-ibm1390,glibc-gconv-ibm1399,\
glibc-gconv-ibm16804,glibc-gconv-ibm256,glibc-gconv-ibm273,\
glibc-gconv-ibm274,glibc-gconv-ibm275,glibc-gconv-ibm277,\
glibc-gconv-ibm278,glibc-gconv-ibm280,glibc-gconv-ibm281,\
glibc-gconv-ibm284,glibc-gconv-ibm285,glibc-gconv-ibm290,\
glibc-gconv-ibm297,glibc-gconv-ibm420,glibc-gconv-ibm423,\
glibc-gconv-ibm424,glibc-gconv-ibm437,glibc-gconv-ibm4517,\
glibc-gconv-ibm4899,glibc-gconv-ibm4909,glibc-gconv-ibm4971,\
glibc-gconv-ibm500,glibc-gconv-ibm5347,glibc-gconv-ibm803,\
glibc-gconv-ibm850,glibc-gconv-ibm851,glibc-gconv-ibm852,\
glibc-gconv-ibm855,glibc-gconv-ibm856,glibc-gconv-ibm857,\
glibc-gconv-ibm860,glibc-gconv-ibm861,glibc-gconv-ibm862,\
glibc-gconv-ibm863,glibc-gconv-ibm864,glibc-gconv-ibm865,\
glibc-gconv-ibm866nav,glibc-gconv-ibm866,glibc-gconv-ibm868,\
glibc-gconv-ibm869,glibc-gconv-ibm870,glibc-gconv-ibm871,\
glibc-gconv-ibm874,glibc-gconv-ibm875,glibc-gconv-ibm880,\
glibc-gconv-ibm891,glibc-gconv-ibm901,glibc-gconv-ibm902,\
glibc-gconv-ibm9030,glibc-gconv-ibm903,glibc-gconv-ibm904,\
glibc-gconv-ibm905,glibc-gconv-ibm9066,glibc-gconv-ibm918,\
glibc-gconv-ibm921,glibc-gconv-ibm922,glibc-gconv-ibm930,\
glibc-gconv-ibm932,glibc-gconv-ibm933,glibc-gconv-ibm935,\
glibc-gconv-ibm937,glibc-gconv-ibm939,glibc-gconv-ibm943,\
glibc-gconv-ibm9448,glibc-gconv-iec-p27-1,glibc-gconv-inis-8,\
glibc-gconv-inis-cyrillic,glibc-gconv-inis,glibc-gconv-isiri-3342,\
glibc-gconv-iso-10367-box,glibc-gconv-iso-11548-1,\
glibc-gconv-iso-2022-cn-ext,glibc-gconv-iso-2022-cn,\
glibc-gconv-iso-2022-jp-3,glibc-gconv-iso-2022-jp,\
glibc-gconv-iso-2022-kr,glibc-gconv-iso-2033,\
glibc-gconv-iso-5427-ext,glibc-gconv-iso-5427,glibc-gconv-iso-5428,\
glibc-gconv-iso646,glibc-gconv-iso-6937-2,glibc-gconv-iso-6937,\
glibc-gconv-iso8859-10,glibc-gconv-iso8859-11,glibc-gconv-iso8859-13,\
glibc-gconv-iso8859-14,glibc-gconv-iso8859-15,glibc-gconv-iso8859-16,\
glibc-gconv-iso8859-1,glibc-gconv-iso8859-2,glibc-gconv-iso8859-3,\
glibc-gconv-iso8859-4,glibc-gconv-iso8859-5,glibc-gconv-iso8859-6,\
glibc-gconv-iso8859-7,glibc-gconv-iso8859-8,glibc-gconv-iso8859-9e,\
glibc-gconv-iso8859-9,glibc-gconv-iso-ir-197,glibc-gconv-iso-ir-209,\
glibc-gconv-johab,glibc-gconv-koi-8,glibc-gconv-koi8-r,\
glibc-gconv-koi8-ru,glibc-gconv-koi8-t,glibc-gconv-koi8-u,\
glibc-gconv-latin-greek-1,glibc-gconv-latin-greek,glibc-gconv-libcns,\
glibc-gconv-libgb,glibc-gconv-libisoir165,glibc-gconv-libjis,\
glibc-gconv-libjisx0213,glibc-gconv-libksc,\
glibc-gconv-mac-centraleurope,glibc-gconv-macintosh,\
glibc-gconv-mac-is,glibc-gconv-mac-sami,glibc-gconv-mac-uk,\
glibc-gconv-mik,glibc-gconv-nats-dano,glibc-gconv-nats-sefi,\
glibc-gconv,glibc-gconv-pt154,glibc-gconv-rk1048,\
glibc-gconv-sami-ws2,glibc-gconv-shift-jisx0213,glibc-gconv-sjis,\
glibc-gconvs,glibc-gconv-t.61,glibc-gconv-tcvn5712-1,\
glibc-gconv-tis-620,glibc-gconv-tscii,glibc-gconv-uhc,\
glibc-gconv-unicode,glibc-gconv-utf-16,glibc-gconv-utf-32,\
glibc-gconv-utf-7,glibc-gconv-viscii\
 \
"

# If we are using this class, we want to ensure that our recipe
# is also properly listed as rproviding the needed results
# Images should not be rproviding anything as they don't result
# in packages, i.e., they are not a dependency resultion element!
python () {
    if bb.data.inherits_class("image", d):
        return

    pn = (d.getVar('PN', True) or "")
    packagelist = (d.getVar('APTGET_ALL_PACKAGES', True) or "").split()
    translations = (d.getVar('APTGET_YOCTO_TRANSLATION', True) or "").split()

    origrprovides = (d.getVar('RPROVIDES_%s' % pn, True) or "").split()
    allrprovides = []
    for p in packagelist:
        appendp = True
        rprovides = [p]
        for t in translations:
            pkg,yocto = t.split(":")
            if p == pkg and yocto:
                rprovides = yocto.split(",")
                break

        for i in rprovides:
            if i and i not in allrprovides:
                allrprovides.append(i)

    if allrprovides:
        s = ' '.join(origrprovides + allrprovides)
        bb.debug(1, 'Setting RPROVIDES_%s = "%s"' % (pn, s))
        d.setVar('RPROVIDES_%s' % pn, s)
}
