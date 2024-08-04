RV_PATH=/data/adb/revanced/${MODDIR##*/}.apk

[ -z "$BASEPATH/base.apk" ] && exit 1

grep "$PKG_NAME" /proc/mounts | while read -r line; do
    mp=${line#* } mp=${mp%% *}
    umount -l "${mp%%\\*}"
done
chcon u:object_r:apk_data_file:s0 "$RV_PATH"
chmod 0755 "$RV_PATH"
mount -o bind "$RV_PATH" "$BASEPATH/base.apk"
