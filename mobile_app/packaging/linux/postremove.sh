#!/bin/sh
# Runs after package removal (deb postrm / rpm %postun).
# Refresh the MIME + desktop databases so the dropped *.smbundle association
# is cleaned out of the caches.
set -e

if command -v update-mime-database >/dev/null 2>&1; then
    update-mime-database /usr/share/mime || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications || true
fi

exit 0
