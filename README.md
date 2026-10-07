[README.md](https://github.com/user-attachments/files/33146921/README.md)
# YTM Player (stage 1)
)
Native QML (Qt 6) YouTube Music client for Linux. No webviews.

**Install once:** run `install.sh` (right-click → Run, or `./install.sh`). After that, launch **YTM Player** from your app menu. No terminal needed.

**Included:** blurred album-art background, spinning cover that pulses to the bass, synced lyrics (LRCLIB) with click-to-seek, bottom/circular visualizer (bars or wave), search, queue from results, shuffle/repeat, volume, and a settings panel (visualizer + background tabs working).

**recently finished) library/playlists, sign-in screen, downloads, other settings tabs, Flatpak packaging.

**Sign-in (for your library,):** put ytmusicapi browser headers in `~/.config/ytm-player/headers_auth.json`. Optional `cookies.txt` in the same folder is passed to yt-dlp.

**Untested:** this was written without being able to run Qt here, so expect a first-run bug or two. The likeliest spot is the audio-sample tap for the visualizer; if it fails, the bars still animate with a placeholder pattern instead of real audio. 

