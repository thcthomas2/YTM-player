"""Finds (or downloads) a JavaScript runtime, which yt-dlp needs to read YouTube."""
import os
import platform
import shutil
import urllib.request
import zipfile
from pathlib import Path

DATA_DIR = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local" / "share"))) / "ytm-player"
LOCAL_DENO = DATA_DIR / "deno"


def find_runtimes():
    """Return {name: {"path": ...}} in the form yt-dlp's js_runtimes option expects."""
    found = {}
    if LOCAL_DENO.exists():
        found["deno"] = {"path": str(LOCAL_DENO)}
    for name, exe in (("deno", "deno"), ("node", "node"), ("bun", "bun"), ("quickjs", "qjs")):
        p = shutil.which(exe)
        if p and name not in found:
            found[name] = {"path": p}
    return found


def install_deno():
    arch = "aarch64" if platform.machine() in ("aarch64", "arm64") else "x86_64"
    url = f"https://github.com/denoland/deno/releases/latest/download/deno-{arch}-unknown-linux-gnu.zip"
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    zpath = DATA_DIR / "deno.zip"
    req = urllib.request.Request(url, headers={"User-Agent": "ytm-player"})
    with urllib.request.urlopen(req, timeout=180) as r, open(zpath, "wb") as f:
        shutil.copyfileobj(r, f)
    with zipfile.ZipFile(zpath) as z:
        z.extract("deno", DATA_DIR)
    zpath.unlink(missing_ok=True)
    os.chmod(LOCAL_DENO, 0o755)


def ensure():
    """Used by install.sh: download deno only if nothing suitable is installed."""
    found = find_runtimes()
    if found:
        print("JavaScript runtime found:", ", ".join(found))
        return
    print("Downloading a JavaScript runtime (about 40 MB)...")
    install_deno()
    print("Done.")


if __name__ == "__main__":
    ensure()
