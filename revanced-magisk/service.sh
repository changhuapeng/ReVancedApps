MODDIR="${0%/*}"
MODNAME="${MODDIR##*/}"
TMPFILE="/data/adb/modules/$MODNAME/module.prop"
. "$MODDIR/utils.sh"

while [ "$(resetprop sys.boot_completed)" != 1 ]; do sleep 1; done
while [ -d "/sdcard/Android" ]; do sleep 1; done
while
    BASEPATH=$(pm path "$PKG_NAME")
    svcl=$?
    [ $svcl = 20 ]
do sleep 2; done
sleep 1

BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
[ -e "$MODDIR/loaded" ] || { check_app && . "$MODDIR/mount.sh"; } || exit 0

W="$(sed -E 's/^description=(\[.*][[:space:]]*)?/description=[ 😅 File is mounted globally because Dynamic mount is not working. ] /g' "$MODDIR/module.prop")"
echo -n "$W" > "$TMPFILE"
