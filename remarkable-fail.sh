#!/bin/bash

# Subshell for the flock lockfile
(

set +o noclobber

flock -n 123

CRASHNUM="$(cat /tmp/crashnum)"
CRASHNUM="$((CRASHNUM + 1))"
echo "$CRASHNUM" > /tmp/crashnum

echo "We've crashed $CRASHNUM times"

if [ "$CRASHNUM" -lt "3" ]; then
    echo "Not crashed enough, letting application try again"
    exit 0;
fi

CURRENTTIME="$(date +%s)"
LASTCRASHTIME="$(cat /tmp/lastcrashtime)"
if [[ -n "$LASTCRASHTIME" ]]; then
    ELAPSED="$(($CURRENTTIME - $LASTCRASHTIME))"
    echo "Last crashed $ELAPSED seconds ago"
    if [[ "$ELAPSED" -gt 600 ]]; then
        echo "Last crash too long ago, not handling it as fatal"
        rm -f /tmp/crashnum
        rm -f /tmp/lastcrashtime
        exit 0
    fi
fi

echo "$CURRENTTIME" > /tmp/lastcrashtime

###################################
# (try to) display the crash splash
echo "Showing crash screen"
touch /tmp/remarkable-crash-reboot
/usr/bin/remarkable-shutdown

########################################################################
# Tell u-boot that we're currently failing, so it should fall back to
# the other partition after the set amount of boot tries.
ACTIVEPART=$(fw_printenv -n active_partition)
CURDEV="$(rootdev)"
CURPART="${CURDEV: -1}"

echo "Running fsck"
if [[ "$CURPART" == "2" ]]; then
    fsck -y /dev/mmcblk1p3
else
    fsck -y /dev/mmcblk1p2
fi

if [ "$CRASHNUM" -gt "5" ]; then
    if [[ "$ACTIVEPART" == "$CURPART" ]] && [[ -n "$(pidof xochitl)" ]]; then
        echo "Unable to fetch upgrade, and we have a fallback to try, falling back"
        fw_setenv upgrade_available 1
        systemctl -f reboot
    fi

    exit 0;
fi

#########################################################
# Both the fallback and the active is apparently failing,
# so try to get an update.

echo "Trying to bring up wifi"
echo 0 > /sys/class/rfkill/rfkill0/soft

systemctl enable dhcpcd
systemctl start dhcpcd

#systemctl enable wpa_supplicant@wlan0
#systemctl start wpa_supplicant@wlan0

while [ "$CRASHNUM" -lt "5" ]; do
    echo "Force upgrade try number $CRASHNUM"
    CRASHNUM=$((CRASHNUM + 1))

    /usr/bin/update_engine_client -check_for_update
    sleep 30

    CURRENTTIME="$(date +%s)"
    ELAPSED="$(($CURRENTTIME - $LASTCRASHTIME))"

    UPDATE_STATUS="$(/usr/bin/update_engine_client -check_for_update)"
    if [[ $UPDATE_STATUS == *"REBOOT"* ]]; then
        echo "We have installed an upgrade"
        if [[ -z "$(pidof xochitl)" ]] && [[ "$ELAPSED" -gt 600 ]]; then
            echo "Upgraded and application not running normally, rebooting"
            systemctl reboot
        fi
    fi


    # Not on wifi, check if there's a fallback partition we can try
    if [[ $UPDATE_STATUS == *"IDLE"* ]] || [[ $UPDATE_STATUS == *"ERROR"* ]]; then
        if [ "$tries" -gt "1" ]; then
            if [[ "$ACTIVEPART" == "$CURPART" ]] && [[ -n "$(pidof xochitl)" ]]; then
                echo "Unable to fetch upgrade, and we have a fallback to try, falling back"
                fw_setenv upgrade_available 1
                systemctl reboot
            fi
        fi
    fi

    if [[ -n "$(pidof xochitl)" ]]; then
        echo "Application back up and running, exiting"
        exit 0
    fi
done

echo "Failed to do anything, just shutting down"

/sbin/poweroff

) 123>/tmp/crashlock
