import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")  # fully customisable controls

from PySide6.QtCore import QUrl
from PySide6.QtGui import QFont, QFontDatabase, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from backend import Backend


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("ytm-player")
    app.setOrganizationName("ytm-player")
    app.setDesktopFileName("ytm-player")
    try:  # prefer a Google-style font when one is installed
        installed = set(QFontDatabase.families())
        for name in ("Google Sans", "Google Sans Text", "Product Sans", "Roboto", "Noto Sans"):
            if name in installed:
                app.setFont(QFont(name, 10))
                break
    except Exception:
        pass
    app.setWindowIcon(QIcon(str(Path(__file__).parent / "assets" / "ytm-player.png")))

    engine = QQmlApplicationEngine()
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(Path(__file__).parent / "qml" / "Main.qml")))
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
