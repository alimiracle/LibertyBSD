#	$OpenBSD: install.md,v 1.41 2015/06/02 19:54:06 rpe Exp $
#
#
# Copyright (c) 1996 The NetBSD Foundation, Inc.
# All rights reserved.
#
# This code is derived from software contributed to The NetBSD Foundation
# by Jason R. Thorpe.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#
# machine dependent section of installation/upgrade script.
#

MDXAPERTURE=2
MDXDM=y
NCPU=$(sysctl -n hw.ncpufound)

((NCPU > 1)) && { DEFAULTSETS="bsd bsd.rd bsd.mp"; SANESETS="bsd bsd.mp"; }

md_installboot() {
	if ! installboot -r /mnt ${1}; then
		echo "\nFailed to install bootblocks."
		echo "You will not be able to boot LibertyBSD from ${1}."
		exit
	fi
}

md_prep_fdisk() {
	local _disk=$1 _q _d

	while :; do
		_d=whole
		if fdisk $_disk | grep -q 'Signature: 0xAA55'; then
			fdisk $_disk
			if fdisk $_disk | grep -q '^..: A6 '; then
				_q=", use the (O)penBSD area,"
				_d=OpenBSD
			fi
		else
			echo "MBR has invalid signature; not showing it."
		fi
		ask "Use (W)hole disk$_q or (E)dit the MBR?" "$_d"
		case $resp in
		w*|W*)
			echo -n "Setting LibertyBSD MBR partition to whole $_disk..."
			fdisk -e ${_disk} <<__EOT >/dev/null
reinit
update
write
quit
__EOT
			echo "done."
			return ;;
		e*|E*)
			# Manually configure the MBR.
			cat <<__EOT

You will now create a single MBR partition to contain your LibertyBSD data. This
partition must have an id of 'A6'; must *NOT* overlap other partitions; and
must be marked as the only active partition.  Inside the fdisk command, the
'manual' command describes all the fdisk commands in detail.

$(fdisk ${_disk})
__EOT
			fdisk -e ${_disk}
			fdisk $_disk | grep -q ' A6 ' && return
			echo No LibertyBSD partition in MBR, try again. ;;
		o*|O*)	return ;;
		esac
	done
}

md_prep_disklabel() {
	local _disk=$1 _f=/tmp/fstab.$1

	md_prep_fdisk $_disk

	disklabel_autolayout $_disk $_f || return
	[[ -s $_f ]] && return

	cat <<__EOT

You will now create an LibertyBSD disklabel inside the LibertyBsd MBR
partition. The disklabel defines how LibertyBsd splits up the MBR partition
into LibertyBsd partitions in which filesystems and swap space are created.
You must provide each filesystem's mountpoint in this program.

The offsets used in the disklabel are ABSOLUTE, i.e. relative to the
start of the disk, NOT the start of the LibertyBsd MBR partition.

__EOT

	disklabel -F $_f -E $_disk
}

md_congrats() {
}

md_consoleinfo() {
	local _u _d=com

	for _u in $(scan_dmesg "/^$_d\([0-9]\) .*/s//\1/p"); do
		if [[ $_d$_u == $CONSOLE || -z $CONSOLE ]]; then
			CDEV=$_d$_u
			CPROM=com$_u
			CTTY=tty0$_u
			return
		fi
	done
}
