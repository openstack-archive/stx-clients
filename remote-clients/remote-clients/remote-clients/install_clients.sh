#!/bin/bash

# 
# Copyright (c) 2016-2017 Wind River Systems, Inc.
#
# SPDX-License-Identifier: Apache-2.0
#
#

skip_req=0

while getopts ":hs" opt; do
    case $opt in
    h)
        echo "Usage:"
        echo "install_clients [OPTION...]"
        echo "-h             show help options"
        echo "-s             skip installing of dependencies through package manager"
        echo ""
        echo "This script installs the remote clients for Titanium Cloud.  It automatically"
        echo "uses the package manager detected on your system to pull in dependencies.  The"
        echo "installation process is dependent on the following packages.  If your system"
        echo "already includes these packages, or you prefer to manage them manually, then"
        echo "you can skip this step by specifying the -s option."
        echo "    python-dev python-setuptools gcc git python-pip libxml2-dev libxslt-dev"
        echo "    libssl-dev libffi-dev libssl-dev"
        echo ""
        echo "If this script is run within a virtualenv then dependent packages will not be"
        echo "installed and client packages will be installed within the virtualenv."
        echo ""
        exit 0
        ;;
    s)
        skip_req=1
        ;;
    \?)
        echo "Invalid option: -$OPTARG, valid options are -h and -s"
        exit 1
        ;;
    esac
done

if [ -z "${VIRTUAL_ENV}" ]; then
    # Determine what type of terminal it is running in
    uname_kernel_name="$(uname -s)"
    case "${uname_kernel_name}" in
        Linux*)     machine=Linux;;
        Darwin*)    machine=Mac;;
        CYGWIN*)    machine=Cygwin;;
        *)          machine="UNKNOWN:${uname_kernel_name}"
    esac
    echo "Running on ${machine}"

    if [[ $EUID != 0 && ${machine} != Cygwin ]]; then
        echo "Root access is required. Please run with sudo or as root."
        exit 1
    fi

    # install tools for the script, like pip
    if [[ skip_req -eq 0 ]]; then
        which apt-get > /dev/null
        aptget_missing=$?
        which yum > /dev/null
        yum_missing=$?

        if [[ "$aptget_missing" == "0" ]]; then
            apt-get install python-dev python-setuptools gcc git libxml2-dev libxslt-dev libssl-dev libffi-dev libssl-dev --no-upgrade || exit 1
            easy_install pip || exit 1
        elif [[ "$yum_missing" == "0" ]]; then
            yum install python-devel python-setuptools gcc git libxml2-devel libxslt-devel openssl-devel libffi-devel || exit 1
            easy_install pip || exit 1
        elif [[ "${machine}" == Cygwin ]]; then
            setup-x86_64.exe -q -P bash_completion -P gcc-core -P git -P libffi-devel -P libxml2 -P libxslt -P openssl-devel || exit 1
        elif [[ "${machine}" == Mac ]]; then
            # If brew does not exist, install homebrew
            which brew > /dev/null
            if [[ $? != "0" ]]; then
                /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || exit 1
            fi

            # Install python 2.7
            # It comes with setuptools, pip, openssl
            su "$SUDO_USER" -c 'brew install python@2' || exit 1
            export PATH="/usr/local/opt/python2/bin:$PATH"

            # Install gcc@4.9
            su "$SUDO_USER" -c 'brew install gcc@4.9' || exit 1
        else
            echo "No supported package managers detected (apt-get, yum, brew)"
            echo "Please ensure the following are installed on your system before continuing:"
            echo "python-dev python-setuptools gcc git python-pip"
            read -p "Continue with installation? y/n: " PACKMAN_CONTINUE_INPUT
            while [[ "$PACKMAN_CONTINUE_INPUT" != "y" && "$PACKMAN_CONTINUE_INPUT" != "n" ]] ; do
                echo invalid input: $PACKMAN_CONTINUE_INPUT
                read -p "Continue with installation? y/n: " PACKMAN_CONTINUE_INPUT
            done
            if [[ "$PACKMAN_CONTINUE_INPUT" == "n" ]]; then
                echo "exiting installer..."
                exit 0
            fi
        fi
    fi
else
    echo "Installing clients to virtual env: ${VIRTUAL_ENV}"
fi

# log standard output and standard error, because there is quite a lot of it
# only output what is being installed and the progress to the console (echo)
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec 3>&1 1>> $SCRIPTDIR/client_installation.log 2>&1

# extract all clients
echo -n Extracting individual clients ... 1>&3

# centos 7 have an issue where the "positional" package does not install
# the pbr requirement. We will manually install it here.
if ! pip install "pbr>=1.8"; then
    echo "Failed to install requirements" 1>&3
    exit 1
fi

while true; do
    echo -n . 1>&3
    sleep 1
done &
trap 'kill $! 2>/dev/null' EXIT
for file in *.tgz ; do
    if ! tar -zxf $file; then
        echo "Failed to extract file $file" 1>&3
        exit 1
    fi
done

if [ -f "requirements.txt" ] ; then
    if ! pip -q install -r requirements.txt -c upper_constraints.txt; then
        echo "Failed to install requirements" 1>&3
        exit 1
    fi
fi
kill $!
echo [DONE] 1>&3

# first remove any clients already installed
# we need to do this in order to downgrade to the ones we are installing
# because some of our tis clients are older than the most recent openstack clients
pip freeze | grep -wF -f installed_clients.txt | xargs pip uninstall -y

for dir in ./*/ ; do
    cd $dir
    if [ -f "setup.py" ] ; then
        echo -n Installing $(python setup.py --name) ... 1>&3
    fi

    while true; do
        echo -n . 1>&3
        sleep 1
    done &
    if [ -f "requirements.txt" ] ; then
        grep -vwF -f ../installed_clients.txt requirements.txt > requirements.txt.temp
        mv requirements.txt.temp requirements.txt
        sed -i -e 's/# Apache-2.0//g' requirements.txt
        if ! pip -q install -r requirements.txt -c ../upper_constraints.txt; then
            echo "Failed to install requirements for $(python setup.py --name)" 1>&3
            exit 1
        fi
    fi

    if [ -f "setup.py" ] ; then
        if ! python setup.py -q install; then
            echo "Failed to install $(python setup.py --name)" 1>&3
            exit 1
        fi
    fi

    # install bash completion
    if [ -d "tools" -a -z "${VIRTUAL_ENV}" ] ; then
        cd tools
            if [ -d "/etc/bash_completion.d" ] ; then
                count=`ls -1 *.bash_completion 2>/dev/null | wc -l`
                if [ $count != 0 ] ; then
                    cp *.bash_completion /etc/bash_completion.d
                fi
            fi
        cd ../
    fi
    kill $!
    echo [DONE] 1>&3
    cd ../
done
