#!/bin/bash 

echo "Installing tfswitch locally"
wget https://raw.githubusercontent.com/warrensbox/terraform-switcher/release/install.sh  #Get the installer on to your machine

chmod 755 install.sh #Make installer executable

./install.sh -b ${WORKSPACE}      #Install tfswitch in a location you have permission

${WORKSPACE}/tfswitch -b ${WORKSPACE}/terraform #or simply tfswitch -b $CUSTOMBIN/terraform 0.11.7

${WORKSPACE}/terraform -v                    #testing version