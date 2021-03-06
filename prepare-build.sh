#!/bin/bash
# Copyright (C) 2015 Florent Revest <revestflo@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

function pull_dir {
    if [ -d $1/.git/ ] ; then
        echo -e "\e[32mPulling $1\e[39m"
        [ "$1" != "." ]   && pushd $1 > /dev/null
        git pull --rebase
        [ $? -ne 0 ] && echo -e "\e[91mError pulling $1\e[39m"
        [ "$1" != "." ]   && popd > /dev/null
    fi
}

function clone_dir {
    if [ ! -d $1 ] ; then
        echo -e "\e[32mCloning branch $3 of $2 in $1\e[39m"
        git clone -b $3 $2 $1
        [ $? -ne 0 ] &&  echo -e "\e[91mError cloning $1\e[39m"
    fi
}

# Update layers in src/
if [[ "$1" == "update" ]]; then
    pull_dir .
    for d in src/*/ ; do
        pull_dir $d
    done
    pull_dir src/oe-core/bitbake
elif [[ "$1" == "git-"* ]]; then
    base=$(dirname $0)
    gitcmd=${1:4} # drop git-
    shift
    for d in $base $base/src/* $base/src/oe-core/bitbake; do
        if [ $(git -C $d $gitcmd "$@" | wc -c) -ne 0 ]; then
            echo -e "\e[35mgit -C $d $gitcmd $@ \e[39m"
            git -C $d $gitcmd "$@"
        fi
    done
# Prepare bitbake
else
    ROOTDIR=`pwd`
    mkdir -p src build/conf

    if [ "$#" -gt 0 ]; then
        export MACHINE=${1}
    else
        export MACHINE=dory
    fi

    # Fetch all the needed layers in src/
    clone_dir src/oe-core              https://github.com/openembedded/openembedded-core.git pyro
    clone_dir src/oe-core/bitbake      https://github.com/openembedded/bitbake.git           1.34
    clone_dir src/meta-openembedded    https://github.com/openembedded/meta-openembedded.git pyro
    clone_dir src/meta-qt5             https://code.qt.io/yocto/meta-qt5.git                 5.9
    clone_dir src/meta-smartphone      https://github.com/shr-distribution/meta-smartphone   pyro
    clone_dir src/meta-asteroid        https://github.com/AsteroidOS/meta-asteroid           master
    clone_dir src/meta-anthias-hybris  https://github.com/AsteroidOS/meta-anthias-hybris     master
    clone_dir src/meta-bass-hybris     https://github.com/AsteroidOS/meta-bass-hybris        master
    clone_dir src/meta-dory-hybris     https://github.com/AsteroidOS/meta-dory-hybris        master
    clone_dir src/meta-lenok-hybris    https://github.com/AsteroidOS/meta-lenok-hybris       master
    clone_dir src/meta-sparrow-hybris  https://github.com/AsteroidOS/meta-sparrow-hybris     master
    clone_dir src/meta-sprat-hybris    https://github.com/AsteroidOS/meta-sprat-hybris       master
    clone_dir src/meta-sturgeon-hybris https://github.com/AsteroidOS/meta-sturgeon-hybris    master
    clone_dir src/meta-swift-hybris    https://github.com/AsteroidOS/meta-swift-hybris       master
    clone_dir src/meta-tetra-hybris    https://github.com/AsteroidOS/meta-tetra-hybris       master
    clone_dir src/meta-wren-hybris     https://github.com/AsteroidOS/meta-wren-hybris        master

    # Create local.conf and bblayers.conf on first run
    if [ ! -e $ROOTDIR/build/conf/local.conf ]; then
        echo -e "\e[32mWriting build/conf/local.conf\e[39m"
        cat >> $ROOTDIR/build/conf/local.conf << EOF
DISTRO = "asteroid"
PACKAGE_CLASSES = "package_ipk"

CONF_VERSION = "1"
BB_DISKMON_DIRS = "\\
    STOPTASKS,\${TMPDIR},1G,100K \\
    STOPTASKS,\${DL_DIR},1G,100K \\
    STOPTASKS,\${SSTATE_DIR},1G,100K \\
    ABORT,\${TMPDIR},100M,1K \\
    ABORT,\${DL_DIR},100M,1K \\
    ABORT,\${SSTATE_DIR},100M,1K" 
PATCHRESOLVE = "noop"
USER_CLASSES = "buildstats image-mklibs image-prelink"
EXTRA_IMAGE_FEATURES = "debug-tweaks"

QT_GIT_PROTOCOL = "https"
EOF
    fi

    if [ ! -e $ROOTDIR/build/conf/bblayers.conf ]; then
        echo -e "\e[32mWriting build/conf/bblayers.conf\e[39m"
        cat > $ROOTDIR/build/conf/bblayers.conf << EOF
LCONF_VERSION = "7"

BBPATH = "\${TOPDIR}"
BBFILES = ""

BBLAYERS = " \\
  $ROOTDIR/src/meta-qt5 \\
  $ROOTDIR/src/oe-core/meta \\
  $ROOTDIR/src/meta-asteroid \\
  $ROOTDIR/src/meta-openembedded/meta-oe \\
  $ROOTDIR/src/meta-openembedded/meta-ruby \\
  $ROOTDIR/src/meta-openembedded/meta-xfce \\
  $ROOTDIR/src/meta-openembedded/meta-gnome \\
  $ROOTDIR/src/meta-smartphone/meta-android \\
  $ROOTDIR/src/meta-openembedded/meta-python \\
  $ROOTDIR/src/meta-openembedded/meta-filesystems \\
  $ROOTDIR/src/meta-anthias-hybris \\
  $ROOTDIR/src/meta-sparrow-hybris \\
  $ROOTDIR/src/meta-sprat-hybris \\
  $ROOTDIR/src/meta-tetra-hybris \\
  $ROOTDIR/src/meta-bass-hybris \\
  $ROOTDIR/src/meta-dory-hybris \\
  $ROOTDIR/src/meta-lenok-hybris \\
  $ROOTDIR/src/meta-sturgeon-hybris \\
  $ROOTDIR/src/meta-swift-hybris \\
  $ROOTDIR/src/meta-wren-hybris \\
  "
EOF
    fi

    # Init build env
    cd src/oe-core
    . ./oe-init-build-env $ROOTDIR/build > /dev/null

    cat << EOF
Welcome to the Asteroid compilation script.

If you meet any issue you can report it to the project's github page:
    https://github.com/AsteroidOS

You can now run the following command to get started with the compilation:
    bitbake asteroid-image

Have fun!
EOF
fi
