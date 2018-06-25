#!/bin/sh -e
DIR=$PWD

DST=/media/zhe/boot
DSR=/media/zhe/rootfs
if [ x"$1" = x"" ] ; then
	echo "Not input sd card boot dir, use default ${DST}"
else
	DST=$1
fi
if [ ! -d ${DST} ] ; then
	echo "${DST} not exsit"
	exit 1
fi

if [ x"$2" = x"" ] ; then
	echo "Not input sd card rootfs dir, use default ${DSR}"
else
	DSR=$2
fi

if [ ! -d ${DSR} ] ; then
	echo "${DSR} not exsit"
	exit 1
fi

. ${DIR}/version.sh

KERNEL_UTS=$(cat ${DIR}/KERNEL/include/generated/utsrelease.h | awk '{print $3}' | sed 's/\"//g' )

untar_pkg () {
	deployfile="-${pkg}.tar.gz"
	case "${pkg}" in
	modules)
		dst_dir=${DSR}/
		;;
	firmware)
		dst_dir=${DSR}/lib/firmware/
		;;
	dtbs)
		dst_dir=${DST}/boot/dtbs/${KERNEL_UTS}/
		;;
	esac

	tar_options="xvf"
	if [ -f "${DIR}/deploy/${KERNEL_UTS}${deployfile}" ] ; then
		echo "tar ${tar_options} ${DIR}/deploy/${KERNEL_UTS}${deployfile} -C ${dst_dir}"
		tar ${tar_options} ${DIR}/deploy/${KERNEL_UTS}${deployfile} -C ${dst_dir}
	else
		exit 3
	fi
}

image="zImage"

# kernel
if [ -f "${DIR}/deploy/${KERNEL_UTS}.${image}" ] ; then
	cp -v ${DIR}/deploy/${KERNEL_UTS}.${image} ${DST}/boot/vmlinuz-${KERNEL_UTS}
	# uEnv.txt
	unset older_kernel
	unset location
	if [ -f "${DST}/boot/uEnv.txt" ] ; then
		location=${DST}/boot/
	elif [ -f "${DST}/uEnv.txt" ] ; then
		location=${DST}/
	fi
	if [ ! "x${location}" = "x" ] ; then
		older_kernel=$(grep uname_r "${location}/uEnv.txt" | grep -v '#' | awk -F"=" '{print $2}' || true)

		if [ ! "x${older_kernel}" = "x" ] ; then
			if [ ! "x${older_kernel}" = "x${KERNEL_UTS}" ] ; then
				sudo sed -i -e 's:uname_r='${older_kernel}':uname_r='${KERNEL_UTS}':g' "${location}/uEnv.txt"
			fi
			echo "info: /boot/uEnv.txt: `grep uname_r ${location}/uEnv.txt`"
		fi
	else
		echo "File uEnv.txt not exsit"
	fi
else
	echo "File [${KERNEL_UTS}.${image}] not exsit"
	exit 1
fi

# dtb
pkg="dtbs"
untar_pkg

# modules
#pkg="modules"
#untar_pkg


