. "$MODDIR/config"

check_app() {
    if BASEPATH=$(pm path "$PKG_NAME"); then
        BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}

        if [ ! -d "$BASEPATH/lib" ]; then
            W="$(sed -E 's/^description=(\[.*][[:space:]]*)?/description=[ ❌ Zygote has crashed. ] /g' "$MODDIR/module.prop")"
            echo -n "$W" > "$TMPFILE"
            return 1
        fi

        VERSION=$(dumpsys package "$PKG_NAME" | grep -m1 versionName) VERSION="${VERSION#*=}"
        if [ "$VERSION" != "$PKG_VER" ] && [ "$VERSION" ]; then
            W="$(sed -E 's/^description=(\[.*][[:space:]]*)?/description=[ ❌ The current version of '"$APP_NAME"' does not match. ] /g' "$MODDIR/module.prop")"
            echo -n "$W" > "$TMPFILE"
            return 1
        fi
    else
        W="$(sed -E 's/^description=(\[.*][[:space:]]*)?/description=[ ❌ '"$APP_NAME"' is not installed. ] /g' "$MODDIR/module.prop")"
        echo -n "$W" > "$TMPFILE"
        return 1
    fi
    return 0
}
