# YTM Player

Native QML (Qt 6) YouTube Music client for Linux. No webviews. Unofficial.

## Install / update
Extract over your existing folder (this keeps the `.venv`), then run `install.sh` (right-click → Run, or `./install.sh`). Re-running it just refreshes the launcher and icon. Launch **YTM Player** from the app menu. `uninstall.sh` removes the launcher.

## Using it
- Top-right pill, left to right: **Library**, **Search**, **Up next**, **Lyrics**, **Visualizer**, **Settings**. Esc closes panels. Ctrl+F opens search.
- **Sign in:** Settings → Account → pick your browser (Firefox is the most reliable). The app copies only your YouTube/Google login cookies into `~/.config/ytm-player/`. Or paste a Cookie header instead.
- **Library:** Liked Songs and your playlists, with Play / Shuffle and a mini player.
- **Queue + autoplay:** playing from search or a playlist fills the queue. When it runs low, similar songs are added automatically (toggle in Settings → Playback or the Up next panel).
- **Tint:** visualizer, progress bar and highlights take their color from the cover (Settings → Appearance).
- **Songs won't load?** Re-run `install.sh` (it installs yt-dlp with its YouTube helper and a small JavaScript runtime, both required now). In the app: Settings → About → Update yt-dlp or Install JavaScript runtime.
- Errors are also written to `~/.config/ytm-player/log.txt`.

## Notes
- Untested on my side (no Qt in my build environment), so report any error text you see.
- Chromium-family browsers may need your keyring unlocked for sign-in to read cookies.
- `packaging/flatpak/` is an untested starting point; the Update yt-dlp button won't work inside a Flatpak.
