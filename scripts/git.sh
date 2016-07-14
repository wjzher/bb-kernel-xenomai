#!/bin/sh -e
#
# Copyright (c) 2009-2016 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

DIR=$PWD

git_kernel_stable () {
	echo "-----------------------------"
	echo "scripts/git: fetching from: ${linux_stable}"
	git fetch "${linux_stable}" master --tags || true
}

git_kernel_torvalds () {
	echo "-----------------------------"
	echo "scripts/git: pulling from: ${torvalds_linux}"
	git pull "${git_opts}" "${torvalds_linux}" master --tags || true
	git tag | grep v"${KERNEL_TAG}" >/dev/null 2>&1 || git_kernel_stable
}

check_and_or_clone () {
	#For Legacy: moving to "${DIR}/ignore/linux-src/" for all new installs
	if [ ! "${LINUX_GIT}" ] && [ -f "${HOME}/linux-src/.git/config" ] ; then
		LINUX_GIT="${HOME}/linux-src"
	fi

	if [ ! "${LINUX_GIT}" ]; then
		if [ -f "${DIR}/ignore/linux-src/.git/config" ] ; then
			echo "-----------------------------"
			echo "scripts/git: LINUX_GIT not defined in system.sh"
			echo "using default location: ${DIR}/ignore/linux-src/"
		else
			echo "-----------------------------"
			echo "scripts/git: LINUX_GIT not defined in system.sh"
			echo "cloning ${torvalds_linux} into default location: ${DIR}/ignore/linux-src"
			git clone "${torvalds_linux}" "${DIR}/ignore/linux-src"
		fi
		LINUX_GIT="${DIR}/ignore/linux-src"
	fi
}

git_kernel () {
	check_and_or_clone

	#In the past some users set LINUX_GIT = DIR, fix that...
	if [ -f "${LINUX_GIT}/version.sh" ] ; then
		unset LINUX_GIT
		echo "-----------------------------"
		echo "scripts/git: Warning: LINUX_GIT is set as DIR:"
		check_and_or_clone
	fi

	#is the git directory user writable?
	if [ ! -w "${LINUX_GIT}" ] ; then
		unset LINUX_GIT
		echo "-----------------------------"
		echo "scripts/git: Warning: LINUX_GIT is not writable:"
		check_and_or_clone
	fi

	#is it actually a git repo?
	if [ ! -f "${LINUX_GIT}/.git/config" ] ; then
		unset LINUX_GIT
		echo "-----------------------------"
		echo "scripts/git: Warning: LINUX_GIT is an invalid tree:"
		check_and_or_clone
	fi

	cd "${LINUX_GIT}/" || exit
	echo "-----------------------------"
	echo "scripts/git: Debug: LINUX_GIT is setup as: [${LINUX_GIT}]."
	echo "scripts/git: [$(cat .git/config | grep url | sed 's/\t//g' | sed 's/ //g')]"
	git fetch || true
	echo "-----------------------------"
	cd "${DIR}/" || exit

	if [ ! -f "${DIR}/KERNEL/.git/config" ] ; then
		rm -rf "${DIR}/KERNEL/" || true
		git clone --shared "${LINUX_GIT}" "${DIR}/KERNEL"
	fi

	#Automaticly, just recover the git repo from a git crash
	if [ -f "${DIR}/KERNEL/.git/index.lock" ] ; then
		rm -rf "${DIR}/KERNEL/" || true
		git clone --shared "${LINUX_GIT}" "${DIR}/KERNEL"
	fi

	cd "${DIR}/KERNEL/" || exit

	if [ "x${git_has_local}" = "xenable" ] ; then
		#Debian Jessie: git version 2.0.0.rc0
		#Disable git's default setting of running `git gc --auto` in the background as the patch.sh script can fail.
		git config --local --list | grep gc.autodetach >/dev/null 2>&1 || git config --local gc.autodetach 0

		#disable git's auto Cleanup, ./KERNEL is a throw away branch...
		git config --local --list | grep gc.auto >/dev/null 2>&1 || git config --local gc.auto 0

		if [ ! "${git_config_user_email}" ] ; then
			git config --local user.email you@example.com
		fi

		if [ ! "${git_config_user_name}" ] ; then
			git config --local user.name "Your Name"
		fi
	fi

	if [ "${RUN_BISECT}" ] ; then
		git bisect reset || true
	fi

	git am --abort || echo "git tree is clean..."
	git add --all
	git commit --allow-empty -a -m 'empty cleanup commit'

	git reset --hard HEAD
	git checkout master -f

	git pull "${git_opts}" || true

	git tag | grep "v${KERNEL_TAG}" | grep -v rc >/dev/null 2>&1 || git_kernel_torvalds

	if [ "${KERNEL_SHA}" ] ; then
		git_kernel_torvalds
	fi

	#CentOS 6.4: git version 1.7.1 (no --list option)
	unset git_branch_has_list
	LC_ALL=C git help branch | grep -m 1 -e "--list" >/dev/null 2>&1 && git_branch_has_list=enable
	if [ "x${git_branch_has_list}" = "xenable" ] ; then
		test_for_branch=$(git branch --list "v${KERNEL_TAG}${BUILD}")
		if [ "x${test_for_branch}" != "x" ] ; then
			git branch "v${KERNEL_TAG}${BUILD}" -D
		fi
	else
		echo "git: the following error: [error: branch 'v${KERNEL_TAG}${BUILD}' not found.] is safe to ignore."
		git branch "v${KERNEL_TAG}${BUILD}" -D || true
	fi

	if [ ! "${KERNEL_SHA}" ] ; then
		git checkout "v${KERNEL_TAG}" -b "v${KERNEL_TAG}${BUILD}"
	else
		git checkout "${KERNEL_SHA}" -b "v${KERNEL_TAG}${BUILD}"
	fi

	if [ "${TOPOFTREE}" ] ; then
		git pull "${git_opts}" "${torvalds_linux}" master || true
		git pull "${git_opts}" "${torvalds_linux}" master --tags || true
	fi

	git describe

	cd "${DIR}/" || exit
}

git_xenomai () {
	IPIPE_GIT="${DIR}/ignore/ipipe"
	XENO_GIT="${DIR}/ignore/xenomai"

# xenomai 2.6.3 now includes ipipe patches for arm 3.8.13, it is no longer
# necessary to pull them in from the ipipe repository
#	echo "-----------------------------"
#	echo "scripts/git: Xenomai ipipe repository"
#
#	# Check/clone/update local ipipe repository
#	if [ ! -f "${IPIPE_GIT}/.git/config" ] ; then
#		rm -rf ${IPIPE_GIT} || true
#		echo "scripts/git: Cloning ${xenomai_ipipe} into ${IPIPE_GIT}"
#		git clone ${xenomai_ipipe} ${IPIPE_GIT}
#	fi
#
#	#Automaticly, just recover the git repo from a git crash
#	if [ -f "${IPIPE_GIT}/.git/index.lock" ] ; then
#		rm -rf ${IPIPE_GIT} || true
#		echo "scripts/git: ipipe repository ${IPIPE_GIT} wedged"
#		echo "Recloning..."
#		git clone ${xenomai_ipipe} ${IPIPE_GIT}
#	fi
#
#	cd "${IPIPE_GIT}"
#	git am --abort || echo "git tree is clean..."
#	git add --all
#	git commit --allow-empty -a -m 'empty cleanup commit'
#
#	git reset --hard HEAD
#	git clean -dXf
#	git checkout master
#
#	test_for_branch=$(git branch --list ipipe-3.8)
#	if [ "x${test_for_branch}" != "x" ] ; then
#		git branch ipipe-3.8 -D
#	fi
#	git checkout --track origin/ipipe-3.8 -f
#
#	git pull ${GIT_OPTS} || true

	echo "-----------------------------"
	echo "scripts/git: Xenomai 2.6 repository"

	# Check/clone/update local xenomai repository
	if [ ! -f "${XENO_GIT}/.git/config" ] ; then
		rm -rf ${XENO_GIT} || true
		echo "scripts/git: Cloning ${xenomai_2_6} into ${XENO_GIT}"
		git clone ${xenomai_2_6} ${XENO_GIT}
	fi

	#Automaticly, just recover the git repo from a git crash
	if [ -f "${XENO_GIT}/ignore/xenomai/.git/index.lock" ] ; then
		rm -rf ${XENO_GIT}/ignore/xenomai/ || true
		echo "scripts/git: xenomai repository ${XENO_GIT} wedged"
		echo "Recloning..."
		git clone ${xenomai_2_6} ${XENO_GIT}
	fi
	cd "${XENO_GIT}"
	git am --abort || echo "git tree is clean..."
	git add --all
	git commit --allow-empty -a -m 'empty cleanup commit'

	git reset --hard HEAD
	git checkout v2.6.3 -f

	# No need to pull latest git now that the officially released and tagged
	# version of xenomai works with the BeagleBone
	#git pull ${GIT_OPTS} || true
}

git_shallow () {
	if [ "x${kernel_tag}" = "x" ] ; then
		echo "error: set kernel_tag in recipe.sh"
		exit 2
	fi
	if [ ! -f "${DIR}/KERNEL/.ignore-${kernel_tag}" ] ; then
		if [ -d "${DIR}/KERNEL/" ] ; then
			rm -rf "${DIR}/KERNEL/" || true
		fi
		mkdir "${DIR}/KERNEL/" || true
		echo "git: [git clone -b ${kernel_tag} https://github.com/RobertCNelson/linux-stable-rcn-ee]"
		git clone --depth=100 -b ${kernel_tag} https://github.com/RobertCNelson/linux-stable-rcn-ee "${DIR}/KERNEL/"
		touch "${DIR}/KERNEL/.ignore-${kernel_tag}"
	fi
}

. "${DIR}/version.sh"
. "${DIR}/system.sh"

#Debian 7 (Wheezy): git version 1.7.10.4 and later needs "--no-edit"
unset git_opts
git_no_edit=$(LC_ALL=C git help pull | grep -m 1 -e "--no-edit" || true)
if [ ! "x${git_no_edit}" = "x" ] ; then
	git_opts="--no-edit"
fi

#CentOS 6.4: git version 1.7.1 (no --local option)
unset git_has_local
LC_ALL=C git help | grep -m 1 -e "--local" >/dev/null 2>&1 && git_has_local=enable

#git 1.7.1 doesnt care if email/user is not set...
if [ "x${git_has_local}" = "xenable" ] ; then
	unset git_config_user_email
	git_config_user_email=$(git config --global --get user.email || true)
	if [ ! "${git_config_user_email}" ] ; then
		git config --local user.email you@example.com
	fi

	unset git_config_user_name
	git_config_user_name=$(git config --global --get user.name || true)
	if [ ! "${git_config_user_name}" ] ; then
		git config --local user.name "Your Name"
	fi
fi

torvalds_linux="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
linux_stable="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"
xenomai_ipipe="https://git.xenomai.org/ipipe.git"
xenomai_2_6="https://git.xenomai.org/xenomai-2.6.git"

if [ ! -f "${DIR}/.yakbuild" ] ; then
	git_kernel
	git_xenomai
else
	. "${DIR}/recipe.sh"
	git_shallow
fi

#
