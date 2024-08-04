MODDIR="${0%/*}"
MODNAME="${MODDIR##*/}"

PROPFILE="/data/adb/modules/$MODNAME/module.prop"
TMPFILE="/data/adb/modules/$MODNAME/revanced.prop"
cp -af "$MODDIR/module.prop" "$TMPFILE"

sed -Ei 's/^description=(\[.*][[:space:]]*)?/description=[ ⛔ Module is not working. ] /g' "$TMPFILE"
flock "$MODDIR/module.prop"

mount --bind "$TMPFILE" "$PROPFILE"

# Remove the temporary loaded file
rm -rf "$MODDIR/loaded"

# Exit with success
exit 0
