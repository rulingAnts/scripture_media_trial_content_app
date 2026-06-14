# Linux file association (`.smbundle`)

Makes the player the default app for `*.smbundle`, so opening one in a file
manager launches the app, which imports it (the bundle path is passed as a
command-line argument and handled in `main()`).

## Install (manual / staging)

```sh
# 1. Register the MIME type
sudo cp scripture-media.xml /usr/share/mime/packages/
sudo update-mime-database /usr/share/mime

# 2. Install the launcher (adjust Exec= for the real install path first)
sudo cp scripture-media-player.desktop /usr/share/applications/
sudo update-desktop-database /usr/share/applications

# 3. (KDE only) refresh the menu cache so Dolphin sees the association
kbuildsycoca6   # or kbuildsycoca5 on Plasma 5
```

Verify:

```sh
xdg-mime query filetype some.smbundle      # -> application/x-smbundle
xdg-mime query default application/x-smbundle  # -> scripture-media-player.desktop
```

> To be folded into the `.deb` packaging in Phase 3 (postinst runs
> `update-mime-database` / `update-desktop-database`).
