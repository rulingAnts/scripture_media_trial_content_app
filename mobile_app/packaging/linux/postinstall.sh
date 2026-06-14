#!/bin/sh
# Runs after package install (deb postinst / rpm %post).
# Refreshes the MIME + desktop databases so the *.smbundle file association
# (application/x-smbundle -> scripture-media-player.desktop) takes effect.
set -e

if command -v update-mime-database >/dev/null 2>&1; then
    update-mime-database /usr/share/mime || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

exit 0
