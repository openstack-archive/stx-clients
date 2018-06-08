#!/bin/bash

# 
# Copyright (c) 2016-2017 Wind River Systems, Inc.
#
# SPDX-License-Identifier: Apache-2.0
#
#

# Determine what type of terminal it is running in
uname_kernel_name="$(uname -s)"
case "${uname_kernel_name}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    *)          machine="UNKNOWN:${uname_kernel_name}"
esac
echo "Running on ${machine}"

if [ -z "${VIRTUAL_ENV}" ]; then
    if [[ $EUID != 0 && ${machine} != Cygwin ]]; then
        echo "Root access is required. Please run with sudo or as root."
        exit 1
    fi
fi

# log standard output and standard error, because there is quite a lot of it
# only output what is being installed and the progress to the console (echo)
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec 3>&1 1>> $SCRIPTDIR/client_uninstallation.log 2>&1

if [ ${machine} == Mac ]; then
    pip freeze | grep -wF -f installed_clients.txt | xargs pip uninstall -y
else
    pip freeze | grep -wF -f installed_clients.txt | xargs --no-run-if-empty pip uninstall -y
fi
