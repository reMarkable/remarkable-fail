#!/bin/bash

echo 0 > /sys/class/rfkill/rfkill0/soft

systemctl enable dhcpcd
systemctl start dhcpcd

systemctl enable wpa_supplicant@wlan0
systemctl start wpa_supplicant@wlan0

while true; do
    /usr/bin/update_engine_client -check_for_update
    sleep 30

    UPDATE_STATUS="$(/usr/bin/update_engine_client -check_for_update)"
    if [[ $UPDATE_STATUS == *"REBOOT"* ]]; then
        systemctl reboot
    fi
done
