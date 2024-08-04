#!/system/bin/sh
MODDIR="${0%/*}"
MODNAME="${MODDIR##*/}"
TMPFILE="/data/adb/modules/$MODNAME/module.prop"
. "$MODDIR/utils.sh"

# API_VERSION = 1
STAGE="$1" # prepareEnterMntNs or EnterMntNs
PID="$2" # PID of app process
UID="$3" # UID of app process
PROC="$4" # Process name. Example: com.google.android.gms.unstable
USERID="$5" # USER ID of app
# API_VERSION = 2
# Enable ash standalone
# Enviroment variables: API_VERSION
# API_VERSION = 3
STAGE="$1" # prepareEnterMntNs or EnterMntNs or OnSetUID
# API_VERSION = 4
# Enviroment variables provided by KernelSU:
# KSU_VERSION - KernelSU version, "-1" is not installed
# KSU_ON_UNMOUNT - true if process is on unmount
# KSU_ON_GRANTED - true if process is granted su access
# For Magisk, please use magisk command, example: MAGISKTMP="$(magisk --path)"

RUN_SCRIPT() {
    case "$STAGE" in
    "prepareEnterMntNs")
        prepareEnterMntNs
        ;;
    "EnterMntNs")
        EnterMntNs
        ;;
    esac
}

prepareEnterMntNs() {
    # this function run on app pre-initialize
    [ "$API_VERSION" -lt 4 ] && exit 1

    if [ "$PROC" == "$PKG_NAME" ] || [ "$UID" -lt 10000 ] || [ "$PROC" == "com.android.systemui" ]; then
        touch "$MODDIR/loaded"
        check_app || exit 1
        W="$(sed -E 's/^description=(\[.*][[:space:]]*)?/description=[ 😋 Dynamic mount is working. ] /g' "$MODDIR/module.prop")"
        echo -n "$W" > "$TMPFILE"
        exit 0
    fi

    # If you want to modify mounts in EnterMntNs, please call exit 0
    exit 1 # close script if we don't need to modify mounts
}

EnterMntNs() {
    # this function will be run when mount namespace of app process is unshared
    BASEPATH=$(pm path "$PKG_NAME")
    BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
    . "$MODDIR/mount.sh"
    exit 1 # close script
}

RUN_SCRIPT
