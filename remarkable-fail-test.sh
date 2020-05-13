#!/bin/bash

source /usr/lib/remarkable-fail/paths-config.sh

if [[ -z "$ROOTFS1" ]] || [[ -z "$ROOTFS2" ]] || [[ -z "$BATTERY_PATH" ]] ; then
    echo "FATAL: paths to system files not set!"
    exit 1
fi

