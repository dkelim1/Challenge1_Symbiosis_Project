#!/usr/bin/bash

apt-get update && apt-get install -y gnupg software-properties-common wget

echo "Installing tfswitch locally"
wget https://raw.githubusercontent.com/warrensbox/terraform-switcher/release/install.sh  #Get the installer on to your machine

chmod 755 install.sh 

./install.sh -b .      

./tfswitch -b terraform 

./terraform -v    
