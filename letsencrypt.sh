#!/bin/bash

if [ -z "$2" ]; then
    echo "Error: IP address is required as the second parameter!"
    exit 1
fi
SERVER_IP="$2"

if [ "$1" == "--remote" ]; then
    # WARNING: For this section to work, port 80 has to be open and accessible via the below mentioned address.
    ssh root@"$SERVER_IP" "
        apt update;
        apt install -y certbot;
        certbot certonly --standalone --noninteractive --agree-tos --email info@outsideworx.net -d sites.outsideworx.net;"
fi
