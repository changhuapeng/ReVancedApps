# Check for installation environment
if ! $BOOTMODE; then
    ui_print "! Installing from Recovery is not supported."
    abort "! Please install this module using your root manager app."
fi

# App variables
. "$MODPATH/config"
STOCK_APK="$MODPATH/app/$PKG_NAME.apk"
RV_APK="$MODPATH/app/base.apk"

if [ -n "$MODULE_ARCH" ] && [ "$MODULE_ARCH" != "$ARCH" ]; then
    ui_print "Your device: $ARCH"
    ui_print "Module: $MODULE_ARCH"
    abort "! ERROR: Wrong arch"
fi

# Process Monitor Tool (PMT) variables
PMT_MODULE_PATH="/data/adb/modules/magisk_proc_monitor"
PMT_VER_CODE="$(grep_prop versionCode "$PMT_MODULE_PATH/module.prop")"
PMT_URL="https://github.com/HuskyDG/magisk_proc_monitor/releases"

# Check Process Monitor Tool
if [ ! -d "/data/adb/modules/magisk_proc_monitor" ]; then
    ui_print "* Process Monitor Tool is not installed."
    abort "! ERROR: Please install it from: $PMT_URL"
fi

if [ "$PMT_VER_CODE" -lt 10 ]; then
    ui_print "* Process Monitor Tool v2.3 or above is required."
    abort "! ERROR: Please upgrade it from: $PMT_URL"
fi

if [ -f "$PMT_MODULE_PATH/disable" ] || [ -f "$PMT_MODULE_PATH/remove" ]; then
    ui_print "* Process Monitor Tool is either not enabled or will be removed."
    abort "! ERROR: Please enable it in your root manager app."
fi

if [ "$ARCH" = "arm" ]; then
    ARCH_LIB=armeabi-v7a
    alias cmpr='$MODPATH/bin/arm/cmpr'
elif [ "$ARCH" = "arm64" ]; then
    ARCH_LIB=arm64-v8a
    alias cmpr='$MODPATH/bin/arm64/cmpr'
elif [ "$ARCH" = "x86" ]; then
    ARCH_LIB=x86
    alias cmpr='$MODPATH/bin/x86/cmpr'
elif [ "$ARCH" = "x64" ]; then
    ARCH_LIB=x86_64
    alias cmpr='$MODPATH/bin/x64/cmpr'
else
    abort "! ERROR: unsupported arch: ${ARCH}"
fi
set_perm_recursive "$MODPATH/bin" 0 0 0755 0777

if su -M -c true >/dev/null 2>/dev/null; then
    alias mm='su -M -c'
else
    alias mm='nsenter -t1 -m'
fi

mm grep "$PKG_NAME" /proc/mounts | while read -r line; do
    ui_print "* Un-mount"
    mp=${line#* } mp=${mp%% *}
    mm umount -l "${mp%%\\*}"
done
am force-stop "$PKG_NAME"

INS=true
if BASEPATH=$(pm path "$PKG_NAME" 2>&1 </dev/null); then
    BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
    if [ "${BASEPATH:1:6}" = system ]; then
        ui_print "* $APP_NAME is a system app"
    elif [ ! -d "${BASEPATH}/lib" ]; then
        ui_print "* Invalid installation found. Uninstalling $PKG_NAME ..."
        pm uninstall -k --user 0 "$PKG_NAME"
    elif [ ! -f "$STOCK_APK" ]; then
        ui_print "* Stock $APP_NAME APK was not found"
        VERSION=$(dumpsys package "$PKG_NAME" | grep -m1 versionName) VERSION="${VERSION#*=}"
        if [ "$VERSION" = "$PKG_VER" ] || [ -z "$VERSION" ]; then
            ui_print "* Skipping stock installation"
            INS=false
        else
            ui_print "* Installed $APP_NAME = $VERSION"
            ui_print "* $APP_NAME module = $PKG_VER"
            abort "! ERROR: Version mismatch"
        fi
    elif cmpr "$BASEPATH/base.apk" "$STOCK_APK"; then
        ui_print "* $APP_NAME is up-to-date"
        INS=false
    fi
fi

install() {
    if [ ! -f "$STOCK_APK" ]; then
        abort "! ERROR: Stock $APP_NAME APK was not found"
    fi
    ui_print "* Updating $APP_NAME to $PKG_VER"
    settings put global verifier_verify_adb_installs 0
    SZ=$(stat -c "%s" "$STOCK_APK")
    if ! SES=$(pm install-create --user 0 -i com.android.vending -r -d -S "$SZ" 2>&1); then
        ui_print "! ERROR: install-create failed"
        abort "$SES"
    fi
    SES=${SES#*[} SES=${SES%]*}
    set_perm "$STOCK_APK" 1000 1000 644 u:object_r:apk_data_file:s0
    if ! op=$(pm install-write -S "$SZ" "$SES" "$PKG_NAME.apk" "$STOCK_APK" 2>&1); then
        ui_print "! ERROR: install-write failed"
        abort "$op"
    fi
    if ! op=$(pm install-commit "$SES" 2>&1); then
        if echo "$op" | grep -q INSTALL_FAILED_VERSION_DOWNGRADE; then
            ui_print "* INSTALL_FAILED_VERSION_DOWNGRADE. Uninstalling..."
            pm uninstall -k --user 0 "$PKG_NAME"
            return 1
        fi
        ui_print "! ERROR: install-commit failed"
        abort "$op"
    fi
    settings put global verifier_verify_adb_installs 1
    if BASEPATH=$(pm path "$PKG_NAME" 2>&1 </dev/null); then
        BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
    else
        abort "! ERROR: Please install $PKG_NAME manually and reinstall this module."
    fi
}
if [ $INS = true ]; then
    if ! install; then
        if ! install; then
            abort
        fi
    fi
fi

BASEPATHLIB=${BASEPATH}/lib/${ARCH}
if [ -z "$(ls -A1 "$BASEPATHLIB")" ]; then
    ui_print "* Extracting native libs"
    mkdir -p "$BASEPATHLIB"
    if ! op=$(unzip -j "$STOCK_APK" lib/"${ARCH_LIB}"/* -d "$BASEPATHLIB" 2>&1); then
        ui_print "ERROR: extracting native libs failed"
        abort "$op"
    fi
    set_perm_recursive "${BASEPATH}/lib" 1000 1000 755 755 u:object_r:apk_data_file:s0
fi
ui_print "* Setting Permissions"
set_perm "$RV_APK" 1000 1000 644 u:object_r:apk_data_file:s0

ui_print "* Setting up $APP_NAME"
mkdir -p "/data/adb/revanced"
mv -f "$RV_APK" "/data/adb/revanced/${MODPATH##*/}.apk"

am force-stop "$PKG_NAME"
ui_print "* Optimising $PKG_NAME"
nohup cmd package compile --reset "$PKG_NAME" >/dev/null 2>&1 &

# Cleanup
ui_print "* Cleaning up"
rm -rf "${MODPATH:?}/app" "${MODPATH:?}/bin"

ui_print "* Install Successful!"
ui_print ""
