#!/usr/bin/env bash
# Removes the launcher and icon. Your login/settings in ~/.config/ytm-player are kept.
rm -f ~/.local/share/applications/ytm-player.desktop ~/.local/share/icons/hicolor/256x256/apps/ytm-player.png
update-desktop-database ~/.local/share/applications 2>/dev/null || true
echo "Launcher removed. You can now delete this folder."
