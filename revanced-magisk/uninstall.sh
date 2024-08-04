#!/system/bin/sh
{
    MODDIR=${0%/*}
    rm "/data/adb/revanced/${MODDIR##*/}".apk
    rmdir "/data/adb/revanced"
} &
