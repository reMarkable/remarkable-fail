#!/bin/bash

echo 0 > /sys/class/rfkill/rfkill0/soft

systemctl enable dhcpcd
systemctl start dhcpcd

systemctl enable wpa_supplicant@wlan0
systemctl start wpa_supplicant@wlan0

tries=0
while [ "$tries" -lt "180" ]; do
    echo "try number $tries"
    tries=$((tries + 1))

    /usr/bin/update_engine_client -check_for_update
    sleep 30

    UPDATE_STATUS="$(/usr/bin/update_engine_client -check_for_update)"
    if [[ $UPDATE_STATUS == *"REBOOT"* ]]; then
        systemctl reboot
    fi
done
