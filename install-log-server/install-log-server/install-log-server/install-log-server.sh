#!/bin/bash
#
# Copyright (c) 2016-2017 Wind River Systems, Inc.
#
# SPDX-License-Identifier: Apache-2.0
#
#

#The following paths are using for package installation
ELASTICSEARCH_RPM_URL=https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/rpm/elasticsearch/2.3.2/elasticsearch-2.3.2.rpm
ELASTICSEARCH_DEB_URL=https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/deb/elasticsearch/2.3.2/elasticsearch-2.3.2.deb
LOGSTASH_RPM_URL=https://download.elastic.co/logstash/logstash/packages/centos/logstash-2.3.4-1.noarch.rpm
LOGSTASH_DEB_URL=https://download.elastic.co/logstash/logstash/packages/debian/logstash_2.3.4-1_all.deb
KIBANA_RPM_URL=https://download.elastic.co/kibana/kibana/kibana-4.5.1-1.x86_64.rpm
KIBANA_DEB_URL=https://download.elastic.co/kibana/kibana/kibana_4.5.1_amd64.deb

printusage () {
    echo "Usage:"
    echo "install-log-server -i <IP Address> [OPTION...]"
    echo "-c   Path to a ca certificate file that logstash will use."
    echo "-h   Show help options."
    echo "-i   The IP address all Elasticsearch, Logstash, Kibana modules will use to bind and publish to."
    echo "-k   Path to a server key file that logstash will use."
    echo "-p   The port Logstash will bind and listen to. Privileged ports are redirected to port 10514."
    echo "-t   Set this system up to receive logs through TCP. (at least one of TCP/TLS or UDP options must be selected)"
    echo "-u   Set this system up to receive logs through UDP. (at least one of TCP/TLS or UDP options must be selected)"
    echo ""
    echo "This utility will install a remote log server and configures communications with Titanium Cloud."
    echo "Refer to the Titanium Cloud System Administration guide and README file for more details."
}

PORT=514 # The default port to align with the Titanium Cloud remote logging component port is 514
while getopts ":c:h:i:k:p:tu" opt; do
    case $opt in
    c)
        CERT_FILE=${OPTARG}
        ;;
    h)
        printusage
        exit 0
        ;;
    i)
        IP_ADDRESS=${OPTARG}
        ;;
    k)
        KEY_FILE=${OPTARG}
        ;;
    p)
        PORT=${OPTARG}
        ;;
    t)
        USE_TCP=true
        ;;
    u)
        USE_UDP=true
        ;;
    \?)
        echo "Invalid option: -$OPTARG, valid options are -h, -i, and -p."
        exit 1
        ;;
    esac
done

# The -i option is mandatory
if [[ -z $IP_ADDRESS ]] ; then
    echo "The IP Address option is mandatory: install-log-server -i <IP Address>"
    # config must set logstash up for SOMETHING
    if [ ! $USE_TCP ] && [ ! $USE_UDP ] ;  then
        echo "and at least one of TCP/TLS or UDP options must also be selected. "
    fi
    printusage
    exit 1
fi

TLS_PARAM_COUNT=0
# to enable TLS, both certificate and key must be provided, not 1 but not the other
if [[ ! -z "$CERT_FILE" ]]; then
    TLS_PARAM_COUNT=$((TLS_PARAM_COUNT+1))
    if [[ ! -e "$CERT_FILE" ]]; then
        echo "$CERT_FILE is not a valid file path."
        printusage
        exit 1
    fi
fi

if [[ ! -z "$KEY_FILE" ]]; then
    TLS_PARAM_COUNT=$((TLS_PARAM_COUNT+1))
    if [[ ! -e "$KEY_FILE" ]]; then
        echo "$KEY_FILE is not a valid file path."
        printusage
        exit 1
    fi
fi

if [ $TLS_PARAM_COUNT -eq 1 ]; then
    echo "Both cert file and key file must be provided for TLS."
    printusage
    exit 1
fi

# TLS is on top of TCP
if [ $TLS_PARAM_COUNT -eq 2 ]; then
    if [ ! $USE_TCP ] ; then
        echo "TLS can only be used with tcp, please also enable TCP by specifying -t"
        printusage
        exit 1
    fi
fi

# config must set logstash up for SOMETHING
if [ ! $USE_TCP ] && [ ! $USE_UDP ] ;  then
    echo "Please specify at least one of -t for TCP and -u for UDP"
    printusage
    exit 1
fi

# wget is required and used for package download which is more reliable
# than downloading packages from the elastic.co repositories.
# One of apt-get or yum package managers is required.
# USE_APT is true when the APT package manager is installed.
USE_APT=false
install_wget=false
install_curl=false
install_iptables_save=false
if [[ ! -z "which wget" ]]; then
    install_wget=true
fi
if [[ ! -z "which curl" ]]; then
    install_curl=true
fi
if [[ "$PORT" -lt "1024" ]];  then
    install_iptables_save=true
fi
YUM_CMD=$(which yum)
APT_GET_CMD=$(which apt-get)
if [[ ! -z $YUM_CMD ]]; then
    PKG_NAME="yum"
    if $install_wget ; then
        echo "wget is required for Java installation."
        yum install wget
    fi
    if $install_iptables_save; then
        echo "iptables-services is required for Logstash with protected ports under 1024."
        yum install iptables-services
    fi
    dist="$(cat /etc/*-release)"
    firewallcmdStatus="$(firewall-cmd --state 2>/dev/null)"
    if [[ "$dist" == *"CentOS"* ]] && [[ "$firewallcmdStatus" == *"running"* ]]; then
        if [ "$USE_TCP" = true ]; then
            firewall-cmd --zone=public --add-port="$PORT"/tcp --permanent
            firewall-cmd --zone=public --add-port=10514/tcp --permanent
        elif [ "$USE_UDP" = true ]; then
            firewall-cmd --zone=public --add-port="$PORT"/udp --permanent
            firewall-cmd --zone=public --add-port=10514/udp --permanent
        fi
        firewall-cmd --reload
    fi
elif [[ ! -z $APT_GET_CMD ]]; then
    PKG_NAME="apt-get"
    USE_APT=true
    if $install_wget ; then
        echo "wget is required for Java installation."
        apt-get install wget
    fi
    if $install_curl ; then
        echo "curl is required for Elasticsearch package download."
        apt-get install curl 
    fi
    if $install_iptables_save; then
        echo "iptables-persistent is required for Logstash with protected ports under 1024."
        apt-get install iptables-persistent
    fi
else
    echo "No supported package managers detected (apt-get, yum)"
    echo "exiting installer..."
    exit 0
fi

get_install_package() {
    # The URL parameter is required for this function
    if [ -z "$1" ]
    then
        return 1
    fi

    PACKAGE_URL=$1
    PACKAGE_FILE=${1##*/}
    echo $PACKAGE_URL
    echo $PACKAGE_FILE
    if $USE_APT ; then
        if [ ! -f "$PACKAGE_FILE" ] ; then
            curl -L -O $PACKAGE_URL
        fi
        dpkg -i $PACKAGE_FILE
    else
        if [ ! -f "$PACKAGE_FILE" ] ; then
            echo Downloading $PACKAGE_URL
            curl -L -O $PACKAGE_URL
            #wget $PACKAGE_URL
        fi
        echo Installing $PACKAGE_FILE
        yum localinstall --nogpgcheck $PACKAGE_FILE
    fi
    return 0
}

boot_at_startup () {
    if [ -z "$1" ]
    then
        echo "A URL parameter must be passed to boot_at_startup"
        return 1
    fi

    SYSTEMCTL=$(which systemctl)
    if [[ ! -z $SYSTEMCTL ]]; then
        systemctl daemon-reload
        echo "Starting $1 with systemctl."
        systemctl enable $1.service
        systemctl restart $1.service
    else
        update-rc.d $1 defaults 95 10
        echo "Starting $1 with update-rc.d."
        /etc/init.d/$1 restart
    fi
}

echo "Checking for required Java version."
if type -p java; then
    _java=java
elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then
    _java="$JAVA_HOME/bin/java"
else
    install_java=y
fi

if [[ "$_java" ]]; then
    # Get java version in format 1.8.0.73
    version=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}'| sed -r 's/[_]+/./g')
    #minimum java version is 1.8.0.73
    min=1.8.0.73
    val=${version}
    if (( ${val%%.*} < ${min%%.*} || ( ${val%%.*} == ${min%%.*} && ${val##*.} < ${min##*.} ) )) ; then
        echo "Elasticsearch recommends that you use the Oracle JDK version 1.8.0_73."
        echo "Refer to the current documentation: https://www.elastic.co/guide/en/elasticsearch/reference/current/_installation.html"
        read -p "Would you like to install Oracle Java 8? y/n: " PACKMAN_CONTINUE_INPUT
        while [[ "$PACKMAN_CONTINUE_INPUT" != "y" && "$PACKMAN_CONTINUE_INPUT" != "n" ]]
        do
            echo invalid input: $PACKMAN_CONTINUE_INPUT
            read -p "Continue with installation? y/n: " PACKMAN_CONTINUE_INPUT
        done
        if [[ "$PACKMAN_CONTINUE_INPUT" == "y" ]]; then
            install_java=y
        fi
    fi
fi

if [[ "$install_java" == "y" ]]; then
    echo "Installing Java:"
    if $USE_APT ; then
        add-apt-repository ppa:webupd8team/java
        apt-get update
        apt-get install oracle-java8-installer
        apt-get install oracle-java8-set-default
    else
        wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u92-b14/jre-8u92-linux-x64.rpm"
        yum localinstall jre-8u92-linux-x64.rpm 
    fi
    echo "Java installation complete."
fi

wait_for_elasticsearch() {
    # elasticsearch can take some time to start
    ES_ACTIVE=false
    echo "Waiting for Elasticsearch to start."
    for i in {1..15}; do
        sleep 2
        response=$(curl -s -XGET "http://${IP_ADDRESS}:9200/_cluster/health?pretty=true")
        if [[ ! "$response" =~ "green" ]] && [[ ! "$response" =~ "yellow" ]]; then
            echo "Waiting for Elasticsearch to start."
        else
            ES_ACTIVE=true
            break 2
        fi
    done
    
    if [ "$ES_ACTIVE" == false ]; then
        echo "Elasticsearch is not responding. Please resolve the issue and rerun the script."
        echo "More details at: https://www.elastic.co/guide/en/elasticsearch/reference/current/cluster-stats.html"
        echo "Refer to the install-log-server README file for more details"
        exit 1
    fi
    echo "Elasticsearch is installed and running."
}
# Install Elasticsearch if necessary
response=$(curl -s -XGET "http://${IP_ADDRESS}:9200/_cluster/health?pretty=true")
if [[ ! "$response" =~ "green" ]] && [[ ! "$response" =~ "yellow" ]]; then
    echo "Installing Elasticsearch."
    if $USE_APT ; then
        get_install_package $ELASTICSEARCH_DEB_URL
    else
        get_install_package $ELASTICSEARCH_RPM_URL
    fi

    # Remove a previously configured network host ip address
    sed -i "/^network.host:.*/d" /etc/elasticsearch/elasticsearch.yml
    # Add the IP address in the elasticsearch config file
    sed -i "/# network.host:.*/a network.host: ${IP_ADDRESS}" /etc/elasticsearch/elasticsearch.yml
    boot_at_startup elasticsearch
    wait_for_elasticsearch
else
    echo "Elasticsearch is already installed and running."
fi

config_logstash() {
    if [ -f "./wrs-logstash.conf" ] ; then
        cp -f ./wrs-logstash.conf /etc/logstash/conf.d/wrs-logstash.conf
    else
        echo "Error: wrs-logstash.conf is missing from install package!"
        exit 1
    fi

    # Fill in the config file based on what transport the user specified
    if [ $USE_TCP ] ;  then
        TCP_PARAMS="tcp {\n    host => \"127.0.0.1\"\n    port => 514\n    #OPTIONAL_TLS_PARAMS\n  }"
        sed -i "s/#TCP_PARAMS/${TCP_PARAMS}/g" /etc/logstash/conf.d/wrs-logstash.conf
    fi

    if [ $USE_UDP ] ;  then
        UDP_PARAMS="udp {\n    host => \"127.0.0.1\"\n    port => 514\n  }"
        sed -i "s/#UDP_PARAMS/${UDP_PARAMS}/g" /etc/logstash/conf.d/wrs-logstash.conf
    fi

    # Update conf file with IP_ADDRESS
    sed -i "s/    host => .*/    host => \"${IP_ADDRESS}\"/" /etc/logstash/conf.d/wrs-logstash.conf
    sed -i "s/.*elasticsearch { hosts.*/    elasticsearch { hosts => [\"${IP_ADDRESS}:9200\"] }/" /etc/logstash/conf.d/wrs-logstash.conf
    
    # install certificate, key, and set TLS config
    if [ $TLS_PARAM_COUNT -eq 2 ]; then
        mkdir -p /etc/pki/tls/certs
        mkdir -p /etc/pki/tls/private
        cp $CERT_FILE /etc/pki/tls/certs/remote-logging-ca-cert.pem
        cp $KEY_FILE /etc/pki/tls/private/remote-logging-server-key.pem
        SSL_PARAMS="ssl_enable => true\n    ssl_verify => false\n    ssl_cert => \"\/etc\/pki\/tls\/certs\/remote-logging-ca-cert.pem\"\n    ssl_key => \"\/etc\/pki\/tls\/private\/remote-logging-server-key.pem\""
        sed -i "s/#OPTIONAL_TLS_PARAMS/${SSL_PARAMS}/g" /etc/logstash/conf.d/wrs-logstash.conf
    fi

    # If the user entered a privileged port then redirect to a non-privileged port logstash can use.
    if [[ "$PORT" -lt "1024" ]];  then
        # Make iptables rules persistent after restart
        if [ -f "/bin/systemctl" ] ; then
            systemctl enable iptables
        else
            update-rc.d iptables defaults 95 10
        fi

        port_in_use=$( netstat -an | grep 10514 )
        if [ -f "/bin/systemctl" ] ; then
             systemctl enable iptables
        else
                update-rc.d iptables defaults 95 10
        fi
        netstat -an | grep 10514
        # Delete any pre-existing rules forwarding to port 10514
        old_rules_list=$(iptables -t nat --line-numbers -L | grep '^[0-9].*10514' | awk '{ print $1 }' | tac)
        old_rules_count=0
        for i in $old_rules_list; do 
            iptables -t nat -D PREROUTING $i
            old_rules_count=$((old_rules_count+1))
        done
        echo Deleted $old_rules_count NAT PREROUTING rules to Logstash listening authorized port 10514.
        
        # Update conf file with non-priviledged port
        echo "Priviledged port $PORT redirected to Logstash listening authorized port 10514."
        sed -i "s/    port =>.*/    port => 10514/" /etc/logstash/conf.d/wrs-logstash.conf
        # Use iptables for IPv4 or ip6tables for IPv6
        if [[ $IP_ADDRESS =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            if [ "$USE_TCP" = true ]; then
                iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
            elif [ "$USE_UDP" = true ]; then
                iptables -A INPUT -p udp --dport "$PORT" -j ACCEPT
            fi
            iptables -t nat -A PREROUTING -p UDP -m udp --dport $PORT -j REDIRECT --to-ports 10514
            iptables -t nat -A PREROUTING -p tcp -m tcp --dport $PORT -j REDIRECT --to-ports 10514
        else
            if [ "$USE_TCP" = true ]; then
                ip6tables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
            elif [ "$USE_UDP" = true ]; then
                ip6tables -A INPUT -p udp --dport "$PORT" -j ACCEPT
            fi
            ip6tables -t nat -A PREROUTING -p UDP -m udp --dport $PORT -j REDIRECT --to-ports 10514
            ip6tables -t nat -A PREROUTING -p tcp -m tcp --dport $PORT -j REDIRECT --to-ports 10514
        fi
        # Save iptables rules permanently (after restart)
        if [ -f "/usr/sbin/netfilter-persistent" ] ; then
            netfilter-persistent save
            netfilter-persistent reload
        elif [ -f "/etc/init.d/iptables-persistent" ] ; then
            /etc/init.d/iptables-persistent save 
            /etc/init.d/iptables-persistent reload
        elif [ -f "/etc/centos-release" ] ; then
            # CentOS 7 https://wiki.centos.org/HowTos/Network/IPTables
            /sbin/service iptables save
        else
            iptables-save
        fi
    fi
}

pidfile="/var/run/logstash.pid"
logstash_running() {
    if [ -f "$pidfile" ] ; then
        echo "Logstash is installed and running."
    else
        echo "Logstash is not responding. Please resolve the issue and rerun the script."
        echo "More details at: https://www.elastic.co/guide/en/logstash/current/installing-logstash.html"
        echo "Refer to the install-log-server README file for more details"
        exit 1
    fi
}

# Install Logstash if necessary
if [ ! -f "$pidfile" ] ; then
    echo "Logstash is being downloaded."
    if $USE_APT ; then
        get_install_package $LOGSTASH_DEB_URL
    else
        get_install_package $LOGSTASH_RPM_URL
    fi
    config_logstash
    boot_at_startup logstash
    logstash_running
else
    config_logstash
    boot_at_startup logstash
    logstash_running
fi

config_kibana() {
    if [ -f "./kibana.svg" ] ; then
        mv -f kibana.svg /opt/kibana/optimize/bundles/src/ui/public/images/kibana.svg
    fi
    sed -i "s/^.*server\.host: .*/server\.host: \"${IP_ADDRESS}\"/" /opt/kibana/config/kibana.yml
    sed -i "s/^.*elasticsearch\.url:.*/elasticsearch\.url: \"http:\/\/${IP_ADDRESS}:9200\"/" /opt/kibana/config/kibana.yml
}

kibana_active=false
kibana_running() {
    kibana_active=$(curl -s -XGET "http://${IP_ADDRESS}:5601")
    if [[ ! "$kibana_active" =~ "false" ]] ; then
        echo "Kibana is installed and running. Updating Kibana settings."
        curl -XPUT http://$IP_ADDRESS:9200/.kibana/index-pattern/logstash-* -d '{"title" : "logstash-*",  "timeFieldName": "@timestamp"}'
        curl -XPUT http://$IP_ADDRESS:9200/.kibana/config/4.5.1 -d '{"defaultIndex" : "logstash-*"}'
        echo
        echo "To begin using the log server, you must enable remote logging on the Titanium Cloud system."
        echo "Kibana provides a web-based interface for using an installed and configured remote log server."
        echo "Open Kibana in your browser http://YOURDOMAIN.com:5601 or http://${IP_ADDRESS}:5601"
        echo "Refer to the Titanium Cloud System Administration guide and README file for additional to start exploring with Kibana."
        echo
    else
        echo "Kibana is not responding. Please resolve the issue and rerun the script."
        echo "More details at: https://www.elastic.co/guide/en/kibana/current/setup.html"
        echo "Refer to the install-log-server README file for more details"
        exit 1
    fi
}

# Install Kibana if necessary
cfgfile="/opt/kibana/config/kibana.yml"
if [ ! -f "$cfgfile" ] ; then
    echo "Kibana is being downloaded."
    if $USE_APT ; then
        get_install_package $KIBANA_DEB_URL
    else
        get_install_package $KIBANA_RPM_URL
    fi
fi

config_kibana
boot_at_startup kibana
kibana_running

exit 0
