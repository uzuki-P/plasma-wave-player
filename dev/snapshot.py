"""Load a copy of the widget offscreen, log its state, and save PNG snapshots.

Usage: python3 -I dev/snapshot.py [--display] [output-dir]
Writes compact.png and full.png. Exits 1 when QML fails to load.
Offscreen rendering drops layer effects such as the rounded album art mask.
--display renders on the session's Wayland display instead, which briefly
opens a test window.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent.parent
args = [a for a in sys.argv[1:] if a != "--display"]
on_display = "--display" in sys.argv
out = Path(args[0] if args else tempfile.gettempdir() + "/waveplayer-snapshot").resolve()
out.mkdir(parents=True, exist_ok=True)
for name in ("compact.png", "full.png"):
    (out / name).unlink(missing_ok=True)

work = Path(tempfile.mkdtemp(prefix="waveplayer-pkg-"))
pkg = work / "package"
shutil.copytree(root / "package", pkg)
main = pkg / "contents/ui/main.qml"
probe = f"""
    Timer {{
        interval: 5000; running: true
        onTriggered: {{
            console.log("PROBE ready", player.ready, "|", player.title, "|", player.identity, "| playing", player.playing,
                "| players", player.players.length, "| bars", cava.values.length, "| streaming", cava.streaming,
                "| error", cava.error, "| art", player.artUrl, "| seed", root.seedColor, "| position", player.position, "/", player.length);
            root.expanded = true;
            grab.start();
        }}
    }}
    Timer {{
        id: grab; interval: 1500
        onTriggered: {{
            const c = root.compactRepresentationItem, f = root.fullRepresentationItem;
            console.log("PROBE sizes", c && c.width, c && c.height, f && f.width, f && f.height);
            if (c) {{
                // Render the compact view at panel size.
                c.anchors.fill = undefined;
                c.width = root.cfg.panelLength;
                c.height = 24;
            }}
            if (c) c.grabToImage(r => console.log("PROBE compact", r.saveToFile("{out}/compact.png")), Qt.size(c.width * 2, c.height * 2));
            if (f) f.grabToImage(r => {{ console.log("PROBE full", r.saveToFile("{out}/full.png")); Qt.quit(); }}, Qt.size(f.width * 2, f.height * 2));
        }}
    }}
}}
"""
text = main.read_text().rstrip()
main.write_text(text[: text.rfind("}")] + probe)

env = dict(os.environ, QT_QPA_PLATFORM="wayland" if on_display else "offscreen", QT_FORCE_STDERR_LOGGING="1",
           QT_LOGGING_RULES="qml.debug=true;js.debug=true")
try:
    result = subprocess.run(["plasmawindowed", str(pkg)], env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
except subprocess.TimeoutExpired as error:
    output = (error.stdout or b"").decode() + (error.stderr or b"").decode()
shutil.rmtree(work)

noise = ("propagateSizeHints", "KWindowShadow", "window masks", "QQmlEngine::quit", "platform plugin", "QT_LOGGING_TO_CONSOLE", "QT_ASSUME")
lines = [line for line in output.splitlines() if line.strip() and not any(n in line for n in noise)]
print("\n".join(lines).replace(str(pkg), "package"))
failed = any("error when loading applet" in line for line in lines)
print(f"snapshots: {out}")
sys.exit(1 if failed else 0)
