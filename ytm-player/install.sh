#!/usr/bin/env bash
# One-time setup: private Python environment + app-menu launcher with icon.
# Safe to re-run after updating the app files.
set -e
cd "$(dirname "$0")"
[ -d .venv ] || python3 -m venv .venv
.venv/bin/pip install -q -U pip
.venv/bin/pip install -q -r requirements.txt
.venv/bin/python -c "import jsruntime; jsruntime.ensure()" || echo "(Couldn't fetch a JavaScript runtime now. You can do it later in the app: Settings -> About.)"
mkdir -p ~/.local/share/applications ~/.local/share/icons/hicolor/256x256/apps
cp assets/ytm-player.png ~/.local/share/icons/hicolor/256x256/apps/ytm-player.png
cat > ~/.local/share/applications/ytm-player.desktop <<DESK
[Desktop Entry]
Type=Application
Name=YTM Player
Comment=YouTube Music client
Exec=$PWD/.venv/bin/python $PWD/main.py
Path=$PWD
Icon=ytm-player
StartupWMClass=ytm-player
Terminal=false
Categories=AudioVideo;Audio;Player;
DESK
update-desktop-database ~/.local/share/applications 2>/dev/null || true
echo "Done. Open 'YTM Player' from your app menu."
