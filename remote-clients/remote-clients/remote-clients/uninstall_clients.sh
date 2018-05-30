#!/bin/bash

# 
# Copyright (c) 2016-2017 Wind River Systems, Inc.
#
# SPDX-License-Identifier: Apache-2.0
#
#

if [ -z "${VIRTUAL_ENV}" ]; then
    if [ $EUID != 0 ]; then
        echo "Root access is required. Please run with sudo or as root."
        exit 1
    fi
fi

# log standard output and standard error, because there is quite a lot of it
# only output what is being installed and the progress to the console (echo)
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec 3>&1 1>> $SCRIPTDIR/client_uninstallation.log 2>&1

pip freeze | grep -wF -f installed_clients.txt | xargs --no-run-if-empty pip uninstall -y
