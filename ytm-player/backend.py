"""YTM Player backend: auth, library, queue/autoplay, playback, lyrics, spectrum, tint."""
import bisect
import hashlib
import json
import math
import os
import random
import re
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
import yt_dlp
from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QColor, QImage
from PySide6.QtMultimedia import QAudioFormat, QAudioOutput, QMediaPlayer
import jsruntime
from yt_dlp.version import __version__ as YTDLP_VERSION
from ytmusicapi import YTMusic

try:  # Qt 6.8+
    from PySide6.QtMultimedia import QAudioBufferOutput
except ImportError:
    QAudioBufferOutput = None

BANDS = 48
FORMATS = ["bestaudio[ext=m4a][abr<=?160]/bestaudio[ext=m4a]/bestaudio", "bestaudio/best", "18/best"]
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "ytm-player"
AUTH_FILE = CONFIG_DIR / "headers_auth.json"
COOKIES_FILE = CONFIG_DIR / "cookies.txt"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "ytm-player" / "audio"
CACHE_KEEP = 60  # most recent songs kept on disk
UA = {"User-Agent": "ytm-player/0.2 (personal project)"}
BROWSER_UA = "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
LRC_LINE = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)")
UPDATE_HINT = " If this keeps happening: Settings → About → Update yt-dlp."


def _get_json(url):
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=8) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception:
        return None


def _hq(url):
    return re.sub(r"=w\d+-h\d+.*$", "=w600-h600-l90-rj", url) if url else ""


def _secs(text):
    try:
        t = 0
        for p in str(text).split(":"):
            t = t * 60 + int(p)
        return t
    except Exception:
        return 0


def _norm(it):
    """Turn a ytmusicapi song/playlist/watch item into the track dict the UI uses."""
    vid = it.get("videoId")
    if not vid or it.get("isAvailable") is False:
        return None
    th = it.get("thumbnails") or it.get("thumbnail") or [{}]
    artists = it.get("artists") or []
    return {
        "videoId": vid,
        "title": it.get("title", ""),
        "artist": ", ".join(a.get("name", "") for a in artists if a and a.get("name")),
        "cover": _hq(th[-1].get("url", "")),
        "thumb": th[0].get("url", ""),
        "duration": it.get("duration_seconds") or _secs(it.get("duration") or it.get("length") or ""),
        "album": (it.get("album") or {}).get("name", "") if isinstance(it.get("album"), dict) else "",
    }


def parse_lrc(text):
    out = []
    for line in text.splitlines():
        m = LRC_LINE.match(line.strip())
        if m:
            out.append({"time": int(m.group(1)) * 60 + float(m.group(2)), "text": m.group(3)})
    return out


def _sapisidhash(cookie, origin="https://music.youtube.com"):
    """Browser-style Authorization value. ytmusicapi uses its presence to recognise
    browser credentials (and recomputes it itself on every request)."""
    m = re.search(r"__Secure-3PAPISID=([^;\s]+)", cookie)
    sapisid = m.group(1) if m else ""
    ts = str(int(time.time()))
    digest = hashlib.sha1(f"{ts} {sapisid} {origin}".encode()).hexdigest()
    return f"SAPISIDHASH {ts}_{digest}"


def _write_headers(cookie):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    AUTH_FILE.write_text(json.dumps({
        "authorization": _sapisidhash(cookie),
        "user-agent": BROWSER_UA,
        "accept": "*/*",
        "accept-language": "en-US,en;q=0.5",
        "content-type": "application/json",
        "x-goog-authuser": "0",
        "x-origin": "https://music.youtube.com",
        "cookie": cookie,
    }))
    os.chmod(AUTH_FILE, 0o600)


def _cached_file(video_id):
    if CACHE_DIR.exists():
        for p in CACHE_DIR.glob(f"{video_id}.*"):
            if p.suffix not in (".part", ".ytdl", ".temp") and p.stat().st_size > 0:
                return p
    return None


def _drop_cached(video_id):
    if CACHE_DIR.exists():
        for p in CACHE_DIR.glob(f"{video_id}.*"):
            p.unlink(missing_ok=True)


def _prune_cache():
    try:
        files = sorted((p for p in CACHE_DIR.iterdir() if p.is_file()), key=lambda p: p.stat().st_mtime, reverse=True)
        for p in files[CACHE_KEEP:]:
            p.unlink(missing_ok=True)
    except Exception:
        pass


class Backend(QObject):
    trackChanged = Signal()
    playingChanged = Signal()
    positionChanged = Signal()
    durationChanged = Signal()
    volumeChanged = Signal()
    lyricsChanged = Signal()
    lyricIndexChanged = Signal()
    spectrumChanged = Signal()
    resultsChanged = Signal()
    statusChanged = Signal()
    modeChanged = Signal()
    queueChanged = Signal()
    queueIndexChanged = Signal()
    playlistsChanged = Signal()
    listChanged = Signal()
    signedInChanged = Signal()
    tintChanged = Signal()
    noticeChanged = Signal()
    jsRuntimeChanged = Signal()

    # worker thread -> main thread
    _searchDone = Signal(list)
    _streamReady = Signal(int, str)
    _lyricsReady = Signal(int, list, bool)
    _failed = Signal(str)
    _radioReady = Signal(int, list, bool)
    _playlistsReady = Signal(list, str)
    _listReady = Signal(dict, list)
    _authDone = Signal(bool, str)
    _tintReady = Signal(int, str)
    _noticeMsg = Signal(str)
    _jsDone = Signal()

    def __init__(self):
        super().__init__()
        self._signed_in = AUTH_FILE.exists()
        self._ytm = self._make_ytm()
        self._pending_ytm = None
        self._results, self._queue, self._index = [], [], -1
        self._token, self._attempt = 0, 0
        self._track = {}
        self._lyrics, self._lyric_times, self._synced, self._lyric_index = [], [], False, -1
        self._status, self._notice, self._tint = "", "", "#ffffff"
        self._shuffle = self._repeat = False
        self._viz, self._autoplay = True, True
        self._radio_busy = self._advance_pending = False
        self._prefetch_busy, self._shuffle_next = False, None
        self._dl_locks, self._lock_guard = {}, threading.Lock()
        self._playlists, self._list_info, self._list_tracks, self._account = [], {}, [], ""
        self._list_filter = ""
        self._volume = 0.8
        self._smooth, self._peak = np.zeros(BANDS), 1e-6
        self._spectrum = [0.0] * BANDS
        self._last_audio = self._last_emit = self._phase = 0.0

        self._audio = QAudioOutput(self)
        self._audio.setVolume(self._volume)
        self._player = QMediaPlayer(self)
        self._player.setAudioOutput(self._audio)

        self._tap = None
        if QAudioBufferOutput is not None:
            self._tap = QAudioBufferOutput(self)
            self._player.setAudioBufferOutput(self._tap)
            self._tap.audioBufferReceived.connect(self._on_audio)

        self._player.positionChanged.connect(self._on_position)
        self._player.durationChanged.connect(lambda _d: self.durationChanged.emit())
        self._player.playbackStateChanged.connect(self._on_state)
        self._player.mediaStatusChanged.connect(self._on_media_status)
        self._player.errorOccurred.connect(self._on_player_error)
        self._searchDone.connect(self._on_search_done)
        self._streamReady.connect(self._on_stream_ready)
        self._lyricsReady.connect(self._on_lyrics_ready)
        self._failed.connect(self._set_status)
        self._radioReady.connect(self._on_radio_ready)
        self._playlistsReady.connect(self._on_playlists_ready)
        self._listReady.connect(self._on_list_ready)
        self._authDone.connect(self._on_auth_done)
        self._tintReady.connect(self._on_tint_ready)
        self._noticeMsg.connect(self._set_notice)
        self._jsDone.connect(self.jsRuntimeChanged)

        self._tick = QTimer(self)
        self._tick.setInterval(33)
        self._tick.timeout.connect(self._tick_fallback)
        self._tick.start()

        if self._signed_in:
            QTimer.singleShot(400, self.loadLibrary)

    # ---------- helpers ----------
    def _make_ytm(self):
        try:
            return YTMusic(str(AUTH_FILE)) if AUTH_FILE.exists() else YTMusic()
        except Exception:
            self._signed_in = False
            return YTMusic()

    def _set_status(self, text):
        self._status = text[:400]
        self.statusChanged.emit()
        if text:
            try:
                CONFIG_DIR.mkdir(parents=True, exist_ok=True)
                with open(CONFIG_DIR / "log.txt", "a") as f:
                    f.write(time.strftime("%H:%M:%S ") + text + "\n")
            except Exception:
                pass

    def _set_notice(self, text):
        self._notice = text
        self.noticeChanged.emit()

    # ---------- properties ----------
    track = Property("QVariantMap", lambda s: s._track, notify=trackChanged)
    playing = Property(bool, lambda s: s._player.playbackState() == QMediaPlayer.PlaybackState.PlayingState, notify=playingChanged)
    position = Property(int, lambda s: int(s._player.position()), notify=positionChanged)
    duration = Property(int, lambda s: int(s._player.duration()), notify=durationChanged)
    lyrics = Property("QVariantList", lambda s: s._lyrics, notify=lyricsChanged)
    lyricsSynced = Property(bool, lambda s: s._synced, notify=lyricsChanged)
    lyricIndex = Property(int, lambda s: s._lyric_index, notify=lyricIndexChanged)
    spectrum = Property("QVariantList", lambda s: s._spectrum, notify=spectrumChanged)
    results = Property("QVariantList", lambda s: s._results, notify=resultsChanged)
    status = Property(str, lambda s: s._status, notify=statusChanged)
    notice = Property(str, lambda s: s._notice, notify=noticeChanged)
    shuffle = Property(bool, lambda s: s._shuffle, notify=modeChanged)
    repeat = Property(bool, lambda s: s._repeat, notify=modeChanged)
    queue = Property("QVariantList", lambda s: s._queue, notify=queueChanged)
    queueIndex = Property(int, lambda s: s._index, notify=queueIndexChanged)
    playlists = Property("QVariantList", lambda s: s._playlists, notify=playlistsChanged)
    listInfo = Property("QVariantMap", lambda s: s._list_info, notify=listChanged)
    listTracks = Property("QVariantList", lambda s: s._visible(), notify=listChanged)
    listFilter = Property(str, lambda s: s._list_filter, notify=listChanged)
    signedIn = Property(bool, lambda s: s._signed_in, notify=signedInChanged)
    accountName = Property(str, lambda s: s._account, notify=signedInChanged)
    tint = Property(str, lambda s: s._tint, notify=tintChanged)
    ytdlpVersion = Property(str, lambda s: YTDLP_VERSION, constant=True)
    jsRuntime = Property(str, lambda s: ", ".join(jsruntime.find_runtimes()) or "none found", notify=jsRuntimeChanged)

    def _get_volume(self):
        return self._volume

    def _set_volume(self, v):
        self._volume = max(0.0, min(1.0, float(v)))
        self._audio.setVolume(self._volume)
        self.volumeChanged.emit()

    volume = Property(float, _get_volume, _set_volume, notify=volumeChanged)

    # ---------- search ----------
    @Slot(str)
    def search(self, query):
        query = query.strip()
        if not query:
            return
        self._set_status("Searching…")

        def work():
            try:
                items = [n for n in (_norm(it) for it in self._ytm.search(query, filter="songs", limit=25)) if n]
                self._searchDone.emit(items)
            except Exception as e:
                self._failed.emit(f"Search failed: {e}")

        threading.Thread(target=work, daemon=True).start()

    @Slot(list)
    def _on_search_done(self, items):
        self._results = items
        self.resultsChanged.emit()
        self._set_status("" if items else "No results")

    # ---------- queue ----------
    def _set_queue(self, tracks, index):
        self._queue = list(tracks)
        self.queueChanged.emit()
        self._play_queue_index(index)

    @Slot(int)
    def playResult(self, i):
        self._set_queue(self._results, i)

    def _visible(self):
        f = self._list_filter.strip().lower()
        if not f:
            return self._list_tracks
        return [t for t in self._list_tracks if f in f"{t['title']} {t['artist']}".lower()]

    @Slot(str)
    def setListFilter(self, text):
        self._list_filter = text
        self.listChanged.emit()

    @Slot(int)
    def playListItem(self, i):
        self._set_queue(self._visible(), i)

    @Slot(int)
    def playQueueItem(self, i):
        self._play_queue_index(i)

    @Slot()
    def playList(self):
        if self._visible():
            self._set_queue(self._visible(), 0)

    @Slot()
    def shuffleList(self):
        vis = self._visible()
        if vis:
            self._shuffle = True
            self.modeChanged.emit()
            self._set_queue(vis, random.randrange(len(vis)))

    @Slot(bool)
    def setAutoplay(self, on):
        self._autoplay = bool(on)

    def _maybe_fill_radio(self):
        if not self._autoplay or self._radio_busy or not self._track:
            return
        if len(self._queue) - self._index - 1 > 2:
            return
        self._radio_busy = True
        threading.Thread(target=self._fetch_radio, args=(self._token, self._track["videoId"], False), daemon=True).start()

    def _fetch_radio(self, tok, video_id, advance):
        tracks = []
        try:
            data = self._ytm.get_watch_playlist(videoId=video_id, radio=True, limit=30)
            tracks = [n for n in (_norm(t) for t in data.get("tracks", [])) if n]
        except Exception as e:
            if advance:
                self._failed.emit(f"Couldn't find more songs: {e}")
        self._radioReady.emit(tok, tracks, advance)

    @Slot(int, list, bool)
    def _on_radio_ready(self, tok, tracks, advance):
        self._radio_busy = False
        have = {t["videoId"] for t in self._queue}
        new = [t for t in tracks if t["videoId"] not in have]
        if new:
            self._queue.extend(new)
            self.queueChanged.emit()
            self._prefetch_next()
        advance = advance or self._advance_pending
        self._advance_pending = False
        if advance and tok == self._token:
            if new and self._index + 1 < len(self._queue):
                self._play_queue_index(self._index + 1)
            else:
                self._set_status("No more songs to play.")

    # ---------- transport ----------
    @Slot()
    def playPause(self):
        if self._player.playbackState() == QMediaPlayer.PlaybackState.PlayingState:
            self._player.pause()
        elif self._player.source().isValid():
            self._player.play()

    @Slot()
    def next(self):
        if not self._queue:
            return
        i = self._next_index()
        if i is not None:
            self._play_queue_index(i)
        elif self._autoplay and self._track:
            self._set_status("Finding something similar…")
            if self._radio_busy:
                self._advance_pending = True
            else:
                self._radio_busy = True
                threading.Thread(target=self._fetch_radio, args=(self._token, self._track["videoId"], True), daemon=True).start()
        else:
            self._play_queue_index(0)

    @Slot()
    def previous(self):
        if not self._queue:
            return
        if self._player.position() > 3000 or self._index <= 0:
            self._player.setPosition(0)
        else:
            self._play_queue_index(self._index - 1)

    @Slot(int)
    def seek(self, ms):
        self._player.setPosition(int(ms))

    @Slot()
    def toggleShuffle(self):
        self._shuffle = not self._shuffle
        self._shuffle_next = None
        self.modeChanged.emit()

    @Slot()
    def toggleRepeat(self):
        self._repeat = not self._repeat
        self.modeChanged.emit()

    @Slot(bool)
    def setVisualizerEnabled(self, on):
        self._viz = bool(on)

    # ---------- playback ----------
    def _play_queue_index(self, i):
        if not (0 <= i < len(self._queue)):
            return
        self._index, self._token, self._attempt = i, self._token + 1, 0
        self._advance_pending = False
        self._shuffle_next = None
        tok, t = self._token, self._queue[i]
        self._track = t
        self.trackChanged.emit()
        self.queueIndexChanged.emit()
        self._player.stop()
        self._apply_lyrics([], False)
        self._set_status("Loading…")
        threading.Thread(target=self._resolve, args=(tok, t["videoId"]), daemon=True).start()
        threading.Thread(target=self._fetch_lyrics, args=(tok, t), daemon=True).start()
        threading.Thread(target=self._fetch_tint, args=(tok, t.get("cover", "")), daemon=True).start()
        self._maybe_fill_radio()

    def _on_player_error(self, _err, msg):
        if self._track:
            _drop_cached(self._track["videoId"])  # don't reuse a file that wouldn't play
        if self._track and self._attempt < 2:
            self._attempt += 1
            self._set_status("Retrying…")
            threading.Thread(target=self._resolve, args=(self._token, self._track["videoId"], self._attempt), daemon=True).start()
        else:
            self._set_status(f"Playback error: {msg}." + UPDATE_HINT)

    def _lock_for(self, video_id):
        with self._lock_guard:
            return self._dl_locks.setdefault(video_id, threading.Lock())

    def _download(self, video_id, attempt=0):
        """Put one track in the cache (or return the cached file). Raises on failure.
        The per-track lock stops a prefetch and a click from downloading the same song twice."""
        with self._lock_for(video_id):
            hit = _cached_file(video_id)
            if hit:
                return str(hit)
            CACHE_DIR.mkdir(parents=True, exist_ok=True)
            base = {"format": FORMATS[min(attempt, 2)], "quiet": True, "noprogress": True, "noplaylist": True,
                    "outtmpl": str(CACHE_DIR / "%(id)s.%(ext)s")}
            runtimes = jsruntime.find_runtimes()
            if runtimes:
                base["js_runtimes"] = runtimes
            plans = [dict(base, cookiefile=str(COOKIES_FILE))] if COOKIES_FILE.exists() else []
            plans.append(base)  # fall back to anonymous if the signed-in attempt fails
            url = f"https://music.youtube.com/watch?v={video_id}"
            last = None
            for opts in plans:
                try:
                    with yt_dlp.YoutubeDL(opts) as y:
                        info = y.extract_info(url, download=True)
                        done = (info.get("requested_downloads") or [{}])[0].get("filepath") or y.prepare_filename(info)
                    _prune_cache()
                    return str(done)
                except Exception as e:
                    last = e
            raise last or RuntimeError("download failed")

    def _resolve(self, tok, video_id, attempt=0):
        try:
            self._streamReady.emit(tok, self._download(video_id, attempt))
        except Exception as e:
            hint = UPDATE_HINT if jsruntime.find_runtimes() else \
                " YouTube needs a JavaScript runtime: Settings → About → Install JavaScript runtime."
            self._failed.emit(f"Couldn't load that track: {e}" + hint)

    def _next_index(self):
        """Which queue slot next() will play (also used to prefetch it)."""
        if not self._queue:
            return None
        if self._shuffle and len(self._queue) > 1:
            if self._shuffle_next is None or self._shuffle_next == self._index or self._shuffle_next >= len(self._queue):
                i = self._index
                while i == self._index:
                    i = random.randrange(len(self._queue))
                self._shuffle_next = i
            return self._shuffle_next
        return self._index + 1 if self._index + 1 < len(self._queue) else None

    def _prefetch_next(self):
        """While a song plays, quietly download the next one or two so skipping is instant."""
        if self._prefetch_busy:
            return
        i = self._next_index()
        if i is None:
            return
        ids = [self._queue[i]["videoId"]]
        if not self._shuffle and i + 1 < len(self._queue):
            ids.append(self._queue[i + 1]["videoId"])
        ids = [v for v in ids if _cached_file(v) is None]
        if not ids:
            return
        self._prefetch_busy = True

        def work():
            try:
                for v in ids:
                    self._download(v)
            except Exception:
                pass
            finally:
                self._prefetch_busy = False

        threading.Thread(target=work, daemon=True).start()

    @Slot(int, str)
    def _on_stream_ready(self, tok, url):
        if tok != self._token:
            return
        self._player.setSource(QUrl.fromLocalFile(url) if url.startswith("/") else QUrl(url))
        self._player.play()
        self._prefetch_next()

    def _on_state(self, _state):
        self.playingChanged.emit()
        if self.playing:
            self._set_status("")

    def _on_media_status(self, st):
        if st == QMediaPlayer.MediaStatus.EndOfMedia:
            if self._repeat:
                self._player.setPosition(0)
                self._player.play()
            else:
                self.next()

    # ---------- album-colour tint ----------
    def _fetch_tint(self, tok, url):
        color = "#ffffff"
        try:
            if url:
                req = urllib.request.Request(url, headers=UA)
                data = urllib.request.urlopen(req, timeout=8).read()
                img = QImage.fromData(data)
                if not img.isNull():
                    img = img.scaled(24, 24)
                    r = g = b = wsum = 0.0
                    for y in range(24):
                        for x in range(24):
                            c = img.pixelColor(x, y)
                            w = c.saturationF() ** 2 * c.valueF() + 0.01
                            r += c.redF() * w
                            g += c.greenF() * w
                            b += c.blueF() * w
                            wsum += w
                    h, s, _v, _a = QColor.fromRgbF(r / wsum, g / wsum, b / wsum).getHsvF()
                    if s < 0.18:
                        color = QColor.fromHsvF(0.0, 0.0, 0.95).name()
                    else:
                        color = QColor.fromHsvF(max(h, 0.0), min(0.7, max(s, 0.4)), 0.95).name()
        except Exception:
            pass
        self._tintReady.emit(tok, color)

    @Slot(int, str)
    def _on_tint_ready(self, tok, color):
        if tok == self._token:
            self._tint = color
            self.tintChanged.emit()

    # ---------- lyrics ----------
    def _fetch_lyrics(self, tok, t):
        lines, synced = [], False
        artist = (t.get("artist") or "").split(",")[0]
        data = _get_json("https://lrclib.net/api/get?" + urllib.parse.urlencode(
            {"track_name": t["title"], "artist_name": artist, "duration": int(t.get("duration") or 0)}))
        if not data or not (data.get("syncedLyrics") or data.get("plainLyrics")):
            res = _get_json("https://lrclib.net/api/search?" + urllib.parse.urlencode({"q": f"{artist} {t['title']}"})) or []
            data = next((r for r in res if r.get("syncedLyrics")), res[0] if res else None)
        if data:
            if data.get("syncedLyrics"):
                lines = parse_lrc(data["syncedLyrics"])
                synced = bool(lines)
            if not lines and data.get("plainLyrics"):
                lines = [{"time": -1, "text": s} for s in data["plainLyrics"].splitlines()]
        self._lyricsReady.emit(tok, lines, synced)

    @Slot(int, list, bool)
    def _on_lyrics_ready(self, tok, lines, synced):
        if tok == self._token:
            self._apply_lyrics(lines, synced)

    def _apply_lyrics(self, lines, synced):
        self._lyrics, self._synced = lines, synced
        self._lyric_times = [l["time"] for l in lines] if synced else []
        self._lyric_index = -1
        self.lyricsChanged.emit()
        self.lyricIndexChanged.emit()

    def _on_position(self, ms):
        self.positionChanged.emit()
        if self._synced and self._lyric_times:
            idx = bisect.bisect_right(self._lyric_times, ms / 1000.0 + 0.15) - 1
            if idx != self._lyric_index:
                self._lyric_index = idx
                self.lyricIndexChanged.emit()

    # ---------- account + library ----------
    @Slot(str)
    def signInFromBrowser(self, browser):
        self._set_notice(f"Reading your {browser} login…")

        def work():
            try:
                from yt_dlp.cookies import YoutubeDLCookieJar, extract_cookies_from_browser
                jar = extract_cookies_from_browser(browser)
                CONFIG_DIR.mkdir(parents=True, exist_ok=True)
                keep = YoutubeDLCookieJar(str(COOKIES_FILE))  # only YouTube/Google cookies are kept
                cookie = {}
                for c in jar:
                    dom = (c.domain or "").lstrip(".")
                    if dom.endswith("youtube.com") or dom.endswith("google.com"):
                        keep.set_cookie(c)
                        if dom.endswith("youtube.com"):
                            cookie[c.name] = c.value
                if "__Secure-3PAPISID" not in cookie:
                    raise RuntimeError(f"no YouTube login found in {browser}. Sign in to music.youtube.com there first")
                keep.save(ignore_discard=True, ignore_expires=True)
                os.chmod(COOKIES_FILE, 0o600)
                _write_headers("; ".join(f"{k}={v}" for k, v in cookie.items()))
                self._finish_auth()
            except Exception as e:
                self._authDone.emit(False, f"Couldn't read {browser}: {e}")

        threading.Thread(target=work, daemon=True).start()

    @Slot(str)
    def signInWithCookie(self, text):
        text = text.strip()
        if text.lower().startswith("cookie:"):
            text = text[7:].strip()
        if "__Secure-3PAPISID" not in text:
            self._set_notice("That doesn't look like a YouTube Music Cookie header (it should contain __Secure-3PAPISID).")
            return
        self._set_notice("Signing in…")
        _write_headers(text)
        threading.Thread(target=self._finish_auth, daemon=True).start()

    def _finish_auth(self):
        try:
            ytm = YTMusic(str(AUTH_FILE))
            ytm.get_library_playlists(limit=1)  # fails if the login is invalid
            name = ""
            try:
                name = ytm.get_account_info().get("accountName", "")
            except Exception:
                pass
            self._pending_ytm = ytm
            self._authDone.emit(True, name)
        except Exception as e:
            self._authDone.emit(False, f"Sign-in didn't work: {e}")

    @Slot(bool, str)
    def _on_auth_done(self, ok, msg):
        if ok:
            self._ytm = self._pending_ytm
            self._signed_in, self._account = True, msg
            self._set_notice("Signed in.")
            self.signedInChanged.emit()
            self.loadLibrary()
        else:
            self._set_notice(msg)
            for f in (AUTH_FILE, COOKIES_FILE):
                f.unlink(missing_ok=True)

    @Slot()
    def signOut(self):
        for f in (AUTH_FILE, COOKIES_FILE):
            f.unlink(missing_ok=True)
        self._ytm = YTMusic()
        self._signed_in, self._account = False, ""
        self._playlists, self._list_info, self._list_tracks, self._list_filter = [], {}, [], ""
        self.signedInChanged.emit()
        self.playlistsChanged.emit()
        self.listChanged.emit()
        self._set_notice("Signed out.")

    @Slot()
    def loadLibrary(self):
        if not self._signed_in:
            return
        self._set_status("Loading your library…")

        def work():
            try:
                out = [{"id": "LM", "title": "Liked Songs", "thumb": "", "count": ""}]
                for p in self._ytm.get_library_playlists(limit=100):
                    pid = p.get("playlistId")
                    if not pid or pid in ("LM", "SE"):
                        continue
                    th = p.get("thumbnails") or [{}]
                    out.append({"id": pid, "title": p.get("title", ""), "thumb": th[0].get("url", ""), "count": str(p.get("count") or "")})
                name = ""
                try:
                    name = self._ytm.get_account_info().get("accountName", "")
                except Exception:
                    pass
                self._playlistsReady.emit(out, name)
            except Exception as e:
                self._failed.emit(f"Couldn't load your library: {e}")

        threading.Thread(target=work, daemon=True).start()

    @Slot(list, str)
    def _on_playlists_ready(self, items, name):
        self._playlists = items
        if name:
            self._account = name
        self.playlistsChanged.emit()
        self.signedInChanged.emit()
        self._set_status("")

    @Slot(str)
    def openPlaylist(self, pid):
        self._set_status("Loading playlist…")

        def work():
            try:
                data = self._ytm.get_liked_songs(limit=500) if pid == "LM" else self._ytm.get_playlist(pid, limit=500)
                tracks = []
                for t in data.get("tracks", []):
                    n = _norm(t)
                    if n:
                        tracks.append(n)
                info = {"id": pid, "title": "Liked Songs" if pid == "LM" else data.get("title", ""),
                        "cover": tracks[0]["cover"] if tracks else ""}
                self._listReady.emit(info, tracks)
            except Exception as e:
                self._failed.emit(f"Couldn't open that playlist: {e}")

        threading.Thread(target=work, daemon=True).start()

    @Slot(dict, list)
    def _on_list_ready(self, info, tracks):
        self._list_info, self._list_tracks, self._list_filter = info, tracks, ""
        self.listChanged.emit()
        self._set_status("")

    # ---------- maintenance ----------
    @Slot()
    def updateYtdlp(self):
        self._set_notice("Updating yt-dlp…")

        def work():
            try:
                r = subprocess.run([sys.executable, "-m", "pip", "install", "-U", "yt-dlp[default]"],
                                   capture_output=True, text=True, timeout=300)
                if r.returncode == 0:
                    self._noticeMsg.emit("yt-dlp is up to date. Restart the app to use the new version.")
                else:
                    last = (r.stderr.strip().splitlines() or ["unknown error"])[-1]
                    self._noticeMsg.emit(f"Update failed: {last}")
            except Exception as e:
                self._noticeMsg.emit(f"Update failed: {e}")

        threading.Thread(target=work, daemon=True).start()

    @Slot()
    def installJsRuntime(self):
        self._set_notice("Downloading a JavaScript runtime (about 40 MB)…")

        def work():
            try:
                jsruntime.install_deno()
                self._noticeMsg.emit("JavaScript runtime installed. Try playing a song again.")
            except Exception as e:
                self._noticeMsg.emit(f"Couldn't install it: {e}")
            self._jsDone.emit()

        threading.Thread(target=work, daemon=True).start()

    # ---------- spectrum ----------
    def _publish(self, vals):
        self._spectrum = [float(v) for v in vals]
        self._last_emit = time.monotonic()
        self.spectrumChanged.emit()

    def _on_audio(self, buf):
        now = time.monotonic()
        if not self._viz or now - self._last_emit < 1 / 30:
            return
        try:
            fmt = buf.format()
            ch = max(1, fmt.channelCount())
            sf = fmt.sampleFormat()
            F = QAudioFormat.SampleFormat
            raw = bytes(buf.constData())[:buf.byteCount()]
            if sf == F.Float:
                x = np.frombuffer(raw, dtype=np.float32)
            elif sf == F.Int16:
                x = np.frombuffer(raw, dtype=np.int16) / 32768.0
            elif sf == F.Int32:
                x = np.frombuffer(raw, dtype=np.int32) / 2147483648.0
            else:
                return
            x = x[: len(x) // ch * ch].reshape(-1, ch).mean(axis=1)[-2048:]
            if len(x) < 2048:
                x = np.pad(x, (2048 - len(x), 0))
            mag = np.abs(np.fft.rfft(x * np.hanning(len(x))))
            edges = np.logspace(math.log10(2), math.log10(len(mag) - 1), BANDS + 1).astype(int)
            bands = np.array([mag[lo:max(hi, lo + 1)].max() for lo, hi in zip(edges[:-1], edges[1:])])
            vals = np.log1p(bands * 20) * np.linspace(0.8, 1.6, BANDS)
            self._peak = max(self._peak * 0.998, float(vals.max()), 1e-6)
            vals = vals / self._peak
            self._smooth = np.maximum(vals, self._smooth * 0.85)
            self._last_audio = now
            self._publish(self._smooth)
        except Exception:
            pass

    def _tick_fallback(self):
        if not self._viz:
            return
        now = time.monotonic()
        if self.playing and now - self._last_audio > 0.4:
            self._phase += 0.18
            fake = np.abs(np.sin(self._phase + np.arange(BANDS) * 0.35) * np.sin(self._phase * 0.7 + np.arange(BANDS) * 0.11))
            self._smooth = np.maximum(fake * 0.8, self._smooth * 0.85)
            self._publish(self._smooth)
        elif not self.playing and self._smooth.max() > 0.01:
            self._smooth *= 0.85
            self._publish(self._smooth)
