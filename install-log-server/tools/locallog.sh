#!/bin/bash
################################################################################
#
# Copyright (c) 2017 Wind River Systems, Inc.
#
# SPDX-License-Identifier: Apache-2.0
#
################################################################################
#
# Description: Changes a running ELK stack system to read in logs from either
#              local log files or from a remote logging server.
#
# Behaviour   : The script takes in a directory or file location, unzips any .tgz
#               files found within the first two directory levels (node files 
#               within a collect file), and unzips any .gz files found within
#               a var/log/ path found inside of the path designated by the user.
#               Each ELK service is restarted, and current elasticsearch indices
#               can optionally be wiped. A custom config file is modified to
#               contain the user-specified filepath, and then logstash is set to
#               begin reading in all logs found, starting from the user-specified 
#               location. Upon completion, the window displaying the logs being 
#               read into logstash will appear to hang up and no new text will be
#               displayed. This is because all files have been read and no new 
#               information is available. It is not currently possible to detect 
#               when this happens and terminate the process. The user can manually
#               terminate the script at this time without their ELK setup/data being 
#               affected. Logstash can be set to read from a remote logging server 
#               as per the settings in wrs-logstash.conf if the remote logging server 
#               had been set up and working with ELK prior to running this script. To
#               return to viewing logs from a remote logger use the --remote command.
#
# This script should be kept in the same directory as the custom config file
# local-logstash.conf, otherwise this script will not be able to edit the config
# file to include the user-specified path.
#
# If after opening the Kibana webpage and clicking "create" on the "Configure an
# index pattern" page and selecting a Time-field name from the drop list and 
# then navigating to the Discover page, if no logs are seen but no errors are 
# displayed either, click the range information at the top right of the page, click 
# "Absolute" on the left side, and then select the date range in which you expect
# the logs to have been created. Alternatively, you can click "Quick" instead of
# "Absolute" and choose one of those options. Kibana looking at too recent of a 
# time range seems to be the most common issue when logs fail to appear after they
# have been read in. 
#
# If you are trying to view logs from a local file and are noticing logs from a
# remote logger appearing in Kibana, check that you do not have any UDP port 
# forwards set up. If you do, your ELK setup will continue to receive data from
# the remote logger while local logs are also being added, and you will simultanesouly
# add data from both sources to the indices and have them viewable in Kibana.
#
# To increase the speed in which logs are read into logstash, near the bottom of
# this script, change -8 to a higher number. This is the number of workers that 
# read through the files within the specified location. The number of workers 
# should correspond to the number of cores you have available, but numbers greater
# than your number of cores still seem to improve the rate at which logs are read
# and parsed.
#
# Dependencies: This script requires that /etc/logstash/conf.d/wrs-logstash.conf
#               exists. This file is initially placed in this location by 
#               install-log-server.sh which is used to set up ELK on your system
#               to receive logs from a remote logger. This file is used to allow
#               logs to be received from a remote server when the --remote option
#               is specified, and further, the IP designated to receive logstash
#               input for remote and local logging is obtained from this file.
#               If logs are being read from local files, ensure local-logstash.conf
#               exists in the same directory as this script.
#
################################################################################
ip=""
suffix=""
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # Directory that this script is contained in
if [ $UID -ne 0 ]; then
  echo $'\tWarning: This script must be run as \'root\' user to restart ELK services. Please rerun with sudo.\n'
  exit 1
fi
# Check to see if required config files are present
if [[ ! -f "/etc/logstash/conf.d/wrs-logstash.conf" ]]; then
    echo $'\tWarning: etc/logstash/conf.d/wrs-logstash.conf does not exist.'
    echo $'\t\t Please make sure you have properly run the install-log-server.sh script.\n'
    exit 1
fi
if [[ ! -f "$DIR""/local-logstash.conf" ]]; then
    echo $'\tWarning: local-logstash.conf does not exist in the directory containing this script.'
    echo $'\t\t Please make sure both of these files are in the same location before re-running.\n'
    exit 1
fi


function help {
    echo ""
    echo "--------------------------------------------------------------------------------------"
    echo "ELK Local Log Setup Script"
    echo ""
    echo "Usage:"
    echo ""
    echo "sudo ./locallog.sh [-clean] [Parent directory containing collect file(s) or location of specific log] [--remote]"
    echo ""
    echo " -clean                   ... wipes all elasticsearch indices clearing the log data shown"
    echo "                              in Kibana. Omitting this will append any newly found log data"
    echo "                              to the log data already seen in Kibana."
    echo "[Location of logs]        ... omitting the square braces, enter the location of a directory"
    echo "                              containing untarred Collect files, or enter the path to a specific"
    echo "                              log file. Drag and dropping files into terminal to get the location"
    echo "                              is supported."
    echo " --remote                 ... directs logstash to acquire logs remotely over the network."
    echo "                              By default the log server created using the install-log-server.sh"
    echo "                              script is connected to using the original configuration file at"
    echo "                              /etc/logstash/conf.d/wrs-logstash.conf"
    echo "                              to use a different server's .conf file please modify this script."
    echo " --help | -h              ... this info"
    echo ""
    echo " As an argument, enter the location of a parent directory containing one or more collect files"
    echo " to have all of the logs contained within the specified path's subdirectories loaded into a local"
    echo " Kibana server. Individual collect files or log files may also be specified."
    echo ""
    echo "Note: Only collect files that have already been untarred can be searched for logs. This script will"
    echo "      take care of unpacking .tgz files found inside of the specified path, as well as unzipping all"
    echo "      .gz files found in any var/log/ path found within any subdirectories."
    echo "      So as to only unpack the initial .tgz file for each node in a collect file, .tgz files will only"
    echo "      be unzipped if they are found within 2 directory-levels from your designated path."
    echo "      if the -clean option is not used, new and old log data will both be visible in Kibana."
    echo ""
    echo "Tips: -If the script is run multiple times without using the -clean option, some logs may not appear in Kibana"
    echo "       initially if their index does not use the same time-field name as the logs added in previous runs of the"
    echo "       script. To see the new logs, in Kibana go to Settings>Add New> Then select the appropriate time-field name"
    echo "       and click Create. The time-field name can be found in the grok statements used to parse your logs."
    echo "      -If you've created an index but no logs appear on the Discover page in Kibana, go to the top right"
    echo "       and modify the date range to include dates you believe might include when the logs were created on"
    echo "       their respective node. The date range being set to too recent an interval is the most common reason"
    echo "       for logs failing to appear."
    echo "      -To keep Kibana populated with previously read-in logs from either local files or a remote logger, simply"
    echo "       omit using -clean, and all logs obtained by the script will be appended to an index and kept in Kibana"
    echo "      -If you feel that log files are being parsed and read too slowly, modify this file at the bottom"
    echo "       and change -w 8 to a larger number. The number should correspond to the number of cores available,"
    echo "       but improvements have been seen with a number greater than the number of cores."
    echo "      -If you use the --remote option and you get an error, make sure that the wrs-logstash.conf file"
    echo "       is in /etc/logstash/conf.d/ or that you modify this script to point to whichever .conf you "
    echo "       originally used when setting up ELK to work with a remote logger."
    echo "      -If you use the --remote option and logs fail to populate, or you get an error about elasticsearch"
    echo "       make sure that the port your remote logger is using is still being forwarded correctly by re-entering"
    echo "       iptables -t nat -A PREROUTING -p UDP -m udp --dport $PORT -j REDIRECT --to-ports 10514" 
    echo "       OR"
    echo "       ip6tables -t nat -A PREROUTING -p tcp -m tcp --dport $PORT -j REDIRECT --to-ports 10514"
    echo "       make sure you correctly specify tcp or udp, and use iptables for IPV4 and ip6tables for IPV6"
    echo "      -If you are noticing new logs from a remote logger present in Kibana even though you are populating it"
    echo "       with local logs, check and delete any UDP port forwards to 514/10514, as these forwards will result in"
    echo "       log data from remote sources being added into your index, even if you are also reading in local logs."
    echo "      -If you have stopped the script from reading from a remote logger but new logs from the remote server"
    echo "       continue to appear in Kibana even though the remote server wasn't connected via UDP, run the -clean"
    echo "       command on its own, then run -clean --remote to get the connection properly established again. Cancelling"
    echo "       and cleaning after this should clear up the issue. This issue seems to occur randomly and does not appear"
    echo "       to result from any particular sequence of events (This issue is not specifc to this script)."
    echo ""
    echo "Examples:"
    echo ""
    echo "sudo ./locallog.sh -clean"
    echo "sudo ./locallog.sh -clean --remote"
    echo "sudo ./locallog.sh -clean /localdisk/Collect/ALL_NODES_20170215.202328/"
    echo "sudo ./locallog.sh --remote  # Will wipe indices and begin receiving logs from remote logger again"
    echo "sudo ./locallog.sh /localdisk/Collect/ALL_NODES_20170215.202328/"
    echo "sudo ./locallog.sh /localdisk/Collect/ALL_NODES_20170215.202328/controller-0_20170215.202328/"
    echo "sudo ./locallog.sh /localdisk/Collect/ALL_NODES_20170215.202328/controller-0_20170215.202328/var/log/sysinv.log"
    echo ""
    echo "Refer to the wiki at: http://wiki.wrs.com/PBUeng/LocalLogsInELK"
    echo "--------------------------------------------------------------------------------------"
    echo ""
    exit 0
}

function localLog {
    # Address of parent directory for collect files to look through
    address="$arg"
    address="${address#\'}" # Remove ' from beginning of address if drag n' dropped into terminal
    address="${address%\'}" # Remove ' from end of address if drag n' dropped into terminal

    # unzips .tgz files within first 2 directory levels from given path. This is intended to unzip the files corresponding
    # to each of the nodes contained in a Collect file.
    for i in $(find "$address" -maxdepth 2 -type f -path '*/*.tgz'); do
        loc="$(readlink -f $i)"
        tar -zxvf "$i" -C "${loc%/*}"
    done

    # This unzips any .gz files found in var/log/ which is where log files are stored (meant for rotated logs)
    for i in $(find "$address" -type f -path '*/var/log/*.gz'); do
        gunzip "$i"
    done

    # Changes suffix to designate whether a directory is being looked through or if an individual log file was specified
    address="\"${address%\/}""$suffix"
    hostAddr="\[\"""$ip""\"\]"
    # Changes the input filepath in the custom config file to point to the user-specified location
    perl -pi -e 's#(^\s*path\s*=> ).*\"#$1'"$address"'#g' "$confLoc" # Replaces current input path in config file with the new one specified
    perl -pi -e 's#(^\s*elasticsearch\s*\{\s*hosts\s*=> ).*#$1'"$hostAddr \}"'#g' "$confLoc" # Replaces current output hosts' address with the one in wrs-logstash.conf

}

# Restarts each of the ELK services
function restart {
    if [[ "${dist}" == *"CentOS"* ]]; then
        echo "Restarting elasticsearch..."
        systemctl restart elasticsearch
        echo "Restarting logstash..."
        systemctl restart logstash
        echo "Restarting kibana..."
        systemctl restart kibana
    elif [[ "${dist}" == *"Ubuntu"* ]]; then
        echo "Restarting elasticsearch..."
        /etc/init.d/elasticsearch status/restart
        echo "Restarting logstash..."
        /etc/init.d/logstash status/restart
        echo "Restarting kibana..."
        /etc/init.d/kibana status/restart
    else
        # If host OS cannot be determined to be CentOS or Ubuntu, run commands for both systems to see if they will work
        echo "Unknown OS detected."
        echo "Attempting all solutions. If none pass, please look up how to restart elasticsearch, logstash and kibana"
        echo "for your system and continue final steps manually."
        echo "Attempting to restart elasticsearch"
        systemctl restart elasticsearch
        /etc/init.d/elasticsearch status/restart
        echo "Attempting to restart logstash"
        systemctl restart logstash
        /etc/init.d/logstash status/restart
        echo "Attempting to restart kibana"
        systemctl restart kibana
        /etc/init.d/kibana status/restart
        sleep 5s # Sleep to give user time to see if any of the restarts passed
    fi
}

# Deletes all indices in elasticsearch (clears logs in Kibana)
function wipeIndices {
    # Changes index API settings to allow indices to be deleted so past local logs aren't always visible
    curl -s -XPUT "$ip"/_cluster/settings -d '{
        "persistent" : {
            "action.destructive_requires_name" : false
        }
    }' > /dev/null
    curl -s -XDELETE "$ip"/_all > /dev/null # Deletes all elasticsearch indices
    echo "Indices wiped"
}

function getIP {
    # Your IP since elasticsearch doesn't always get hosted at localhost
    origConf="/etc/logstash/conf.d/wrs-logstash.conf"
    if [[ "${dist}" == *"CentOS"* ]] || [[ "${dist}" == *"Ubuntu"* ]]; then
        # Pulls IP from output specified in wrs-logstash.conf
        ip=$(perl -ne'/(?:^\s*elasticsearch\s*\{\s*hosts\s*=> )(.*)/ and print $1' "$origConf")
    else
        read -p "Enter the IP that ELK modules will bind and publish to: " ip
    fi
    ip="${ip#[\"}"
    ip="${ip%\"] \}}"
}
echo ""
# Determines which OS you are using and runs the corresponding reset commands
dist="$(lsb_release -a)"
while [[ $# > 0 ]]; do
    arg="$1"
    case $arg in
        
        -h|--help)
        help
        ;;

        --remote)
        confLoc="/etc/logstash/conf.d/wrs-logstash.conf"
        restart
        break
        ;;

        -clean)
        getIP
        wipeIndices
        if [ -z "$2" ]; then # If no arguments follow -clean then exit
            echo "Error: Log path not specified."
            exit 1
        fi
        #exit 0
        ;;

        *)
        getIP
        confLoc="$DIR""/local-logstash.conf" # Location of the custom config file
        # Sets the config file to either look for logs in subdirectories or just a single specified log
        if [[ -f "$arg" ]]; then
            suffix="\""
        elif [[ -d "$arg" ]]; then
            suffix="/**/*.log*\""
        else
            printf "Unknown input.\nTerminating...\n"
            exit 1
        fi
        localLog
        restart
        break
    esac
    shift
done
echo "Reading logs..."
# Changes which config file logstash reads in and sets the number of workers to 8
/opt/logstash/bin/logstash -f "$confLoc" -w 8
exit
