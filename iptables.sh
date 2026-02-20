#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
if [ -z "$2" ]; then
    echo "Error: IP address is required as the second parameter!"
    exit 1
fi
SERVER_IP="$2"

if [ "$1" == "--deploy" ]; then
    # WARNING: For this section to work, sites needs to be deployed.
    echo "Uploading configuration: $SERVER_IP"
    rsync -rvh \
        "$SCRIPT_DIR/blacklist.txt" \
        root@"$SERVER_IP":/home/outsideworx/sites
    echo "Deployment starts: $SERVER_IP"
    ssh root@"$SERVER_IP" "
        BLACKLIST_FILE='/home/outsideworx/sites/blacklist.txt'
        CHAIN='APACHE_BLACKLIST'
        if ! iptables -L \"\$CHAIN\" -n >/dev/null 2>&1; then
            iptables -N \"\$CHAIN\"
        fi
        iptables -F \"\$CHAIN\"
        if ! iptables -C INPUT -j \"\$CHAIN\" >/dev/null 2>&1; then
            iptables -I INPUT 1 -j \"\$CHAIN\"
        fi
        while IFS= read -r ip; do
            [ -z \"\$ip\" ] && continue
            iptables -A \"\$CHAIN\" -s \"\$ip\" -j DROP
        done < \"\$BLACKLIST_FILE\"
        iptables -L APACHE_BLACKLIST -n -v"
else
    echo "Error: Only deploy mode is supported!"
    exit 1
fi
