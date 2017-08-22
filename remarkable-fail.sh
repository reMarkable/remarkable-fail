#!/bin/bash

###################################
# (try to) display the crash splash
touch /tmp/remarkable-crash-reboot
/usr/bin/remarkable-shutdown

########################################################################
# Tell u-boot that we're currently failing, so it should fall back to
# the other partition after the set amount of boot tries.
ACTIVEPART=$(fw_printenv -n active_partition)
CURDEV="$(rootdev)"
CURPART="${CURDEV: -1}"

if [[ "$ACTIVEPART" == "$CURPART" ]]; then
    fw_setenv upgrade_available 1
    systemctl reboot
fi

#########################################################
# Both the fallback and the active is apparently failing,
# so try to get an update.

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

/sbin/poweroff
