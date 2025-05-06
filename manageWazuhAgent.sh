#!/bin/bash

# Creator: Pedro Reina
# Date: 2025-05-06
# Description: Automates the process of deploying wazuh agents in linux depending on architecture and package system for Wazuh version 4.11.2

# WARNING: IF THE VERSION OF THE SERVER IS NOT 4.11.2 PLEASE CHANGE THE 'wazuhServerVersion' VARIABLE

### Wazuh Server Version ###
# Set the wazuh server version to get the package
wazuhServerVersion="4.11.2"
###

### Wazuh Agent Deploy Info ###
# declare the variables for Wazuh info for deploy the package
unset wazuhManager
unset wazuhAgentGroup
unset wazuhAgentName
###


# Install Wazuh-Agent in systems with dpkg package manager
function installPackageDPKG()
{
    # Get the server root version from the wazuhServerVersion, if it is 4.11.2 root version is 4, or is 3.5 root version is 3
    rootVersion=${wazuhServerVersion:0:1}

    # System Architecture get from installWazuhAgent function
    systemArch=$1

    echo "Getting Wazuh Agent package..."
    wget -q "https://packages.wazuh.com/$rootVersion.x/apt/pool/main/w/wazuh-agent/wazuh-agent_$wazuhServerVersion-1_$systemArch.deb" 2>/dev/null
    
    # if it can't find the package it don't install it
    if [ $? -eq 0 ] && [ -e "./wazuh-agent_$wazuhServerVersion-1_$systemArch.deb" ]; then

        echo "Installing Wazuh Agent package..."

        # get the Wazuh info for deploy the package
        echo "[Mandatory] Set the server address, enter an IP address or a FQDN"
        while [ -z $wazuhManager  ]; do
            read -p "-> " wazuhManager
        done

        echo "[Optional] Set Agent's Name, if not set takes hostname"
        read -p "-> " wazuhAgentName

        echo "[Optional] Set Agent's group/s, is there more than one group use <group1,group2,...> format"
        read -p "-> " wazuhAgentGroup

        echo "Setting the configuration and finshing installing..."

        # Export the env variables that needs 
        export WAZUH_MANAGER=$wazuhManager 
        export WAZUH_AGENT_GROUP=$wazuhAgentGroup
        export WAZUH_AGENT_NAME=$wazuhAgentName
        dpkg -i "./wazuh-agent_$wazuhServerVersion-1_$systemArch.deb"
        # if the package don't install show an error and exists
        if [ $? -ne 0 ]; then
            echo "ERROR: Could not install the package, check the package name"
            exit 1
        fi
    else
        echo "ERROR: Could not get the package, check the url and versions please"
        exit 1
    fi
    echo "Instalation finished"
    echo "Use $0 start to start the connection to the server"
}

# Install Wazuh-Agent in systems with rpm package manager
function installPackageRPM()
{
    # Get the server root version from the wazuhServerVersion, if it is 4.11.2 root version is 4, or is 3.5 root version is 3
    rootVersion=${wazuhServerVersion:0:1}

    # System Architecture
    systemArch=$1
    
    echo "Getting Wazuh Agent package..."
    curl -o wazuh-agent-4.11.2-1.x86_64.rpm "https://packages.wazuh.com/$rootVersion.x/yum/wazuh-agent-$wazuhServerVersion-1.$systemArch.rpm"  2>/dev/null

    if [ $? -eq 0 ] && [ -e "./wazuh-agent-$wazuhServerVersion-1.$systemArch.rpm" ]; then
        echo "Installing Wazuh Agent package..."
        # get the Wazuh info for deploy the package
        echo "[Mandatory] Set the server address, enter an IP address or a FQDN"
        while [ -z $wazuhManager  ]; do
            read -p "-> " wazuhManager
        done

        echo "[Optional] Set Agent's Name, if not set takes hostname"
        read -p "-> " wazuhAgentName

        echo "[Optional] Set Agent's group/s, is there more than one group use <group1,group2,...> format"
        read -p "-> " wazuhAgentGroup

        echo "Setting the configuration and finshing installing..."
        # Export the env variables that needs 
        export WAZUH_MANAGER=$wazuhManager 
        export WAZUH_AGENT_GROUP=$wazuhAgentGroup
        export WAZUH_AGENT_NAME=$wazuhAgentName
        rpm -ihv wazuh-agent-4.11.2-1.x86_64.rpm
        # if the package don't install show an error and exists
        if [ $? -ne 0 ]; then
            echo "ERROR: Could not install the package, check the package name"
            exit 1
        fi
    else
        echo "ERROR: Could not get the package, check the url and versions please"
    fi
}

# Check what package manager uses the system, then chack system architecture and call install package for each package manager and set the architecture
# if the package changes architecture name please changeit
function installWazuhAgent()
{   
    # check if uses dpkg, checkin if ls .deb package exists
    if dpkg -S ls >/dev/null 2>&1
        then
            # takes the architecture
            case "$(uname -m)" in
                x86_64)
                    installPackageDPKG "amd64";;
                amd64)
                    installPackageDPKG "amd64";;
                aarch64)
                    installPackageDPKG "arm64";;
                # if the architecture dont found show error and exists
                *)
                    echo "ERROR: Don't know how to handle $(uname -m)"
                    exit 1
                ;;
            esac
     # check if uses rpn, checkin if ls .rpm package exists
    elif rpm -q -f /bin/ls >/dev/null 2>&1
        then
            case "$(uname -m)" in
            # takes the architecture
                x86_64)
                    installPackageRPM "x86_64";;
                amd64)
                    installPackageRPM "x86_64";;
                aarch64)
                    installPackageRPM "aarch64";;
                # if the architecture dont found show error and exists
                *)
                    echo "ERROR: Don't know how to handle $(uname -m)"
                    exit 1
                ;;
            esac
    # if the package manager dont exits show error and exists
    else
        echo "ERROR: Don't know this manager system (neither RPM nor DEB)."
        exit 1
    fi
}

# show a stdout help for the user
function showHelp()
{
    echo -e "\
This is a usage to explain how $1 is executed\n\n\
\tinstall -> Get the Wazuh-Agent package and install it with the parameters readed from stdin
\tuninstall -> Uninstall the Wazuh-Agent package
\tstart -> Start Wazuh-Agent service
\tstop -> Stop Wazuh-Agent service
\tstatus -> Get the Wazuh-Agent service status
\thelp -> Show this usage, no require sudo or root

Use $1 <option> with sudo or root user"
}

# reload the daemon and start the service, if teh system uses SysV change this function or do it manually
function startWazuhAgentService()
{
    systemctl daemon-reload
    systemctl enable wazuh-agent
    systemctl start wazuh-agent
}

# main function
# it takes the parameters and 
function main()
{
    if [ -n "$SUDO_USER" ] || [ "$USER" = "root" ]; then
        case $1 in
            install)
                installWazuhAgent;;
            uninstall)
                dpkg --purge wazuh-agent;;
            start)
                startWazuhAgentService;;
            stop)
                systemctl stop wazuh-agent;;
            restart)
                systemctl restart wazuh-agent;;
            status)
                systemctl status wazuh-agent;;
            *)
                echo "ERROR: Not a valid option execute $0 help to show a usage"
                exit 1
            ;;
        esac
    elif [ "$1" = "help" ]; then
        showHelp $0
    else
        echo "ERROR: This script need sudo or root privileges to execute"
        exit 1
    fi
}

# check if there are more than an argument and calls main
if [ $# -eq 1 ]; then
    main $1
else
    echo "ERROR: The scrip need a valid option execute $0 help to show a usage"
fi
