import QtQuick
import QtWebSockets
import org.kde.plasma.plasma5support as P5Support

// Runs tools/cava-bridge while `active` is true and exposes its frames
// as `values`, normalized to 0..1. When CAVA stops, the values decay to zero.
Item {
    id: root

    property bool active: false
    property int bars: 48
    property int framerate: 60

    property var values: []
    property bool streaming: false
    property string error: ""

    readonly property string bridgePath: Qt.resolvedUrl("../tools/cava-bridge").toString().replace("file://", "")
    property string token: ""
    property var socket: null

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'";
    }

    function start() {
        stop();
        if (!active || !server.url.toString()) {
            return;
        }
        token = Math.random().toString(36).slice(2) + Date.now().toString(36);
        const command = ["python3", bridgePath, server.url.toString(), token, bars, framerate].map(shellQuote).join(" ");
        executable.connectSource(command);
    }

    function stop() {
        token = "";
        streaming = false;
        if (socket) {
            // Clear it first so the close handler doesn't schedule a retry.
            const ws = socket;
            socket = null;
            ws.active = false;
        }
        for (const source of executable.connectedSources.slice()) {
            executable.disconnectSource(source);
        }
    }

    function handle(ws, message) {
        if (message.startsWith("HELLO ")) {
            if (token && message.slice(6) === token) {
                socket = ws;
                error = "";
            } else {
                ws.active = false;
            }
            return;
        }
        if (ws !== socket) {
            return;
        }
        if (message.startsWith("ERR ")) {
            error = message.slice(4);
            return;
        }
        const parts = message.split(";");
        const next = [];
        for (const part of parts) {
            if (part !== "") {
                next.push(parseInt(part, 10) / 1000);
            }
        }
        values = next;
        streaming = true;
    }

    onActiveChanged: restartTimer.restart()
    onBarsChanged: restartTimer.restart()
    onFramerateChanged: restartTimer.restart()

    Timer {
        id: restartTimer
        interval: 150
        onTriggered: root.active ? root.start() : root.stop()
    }

    Timer {
        id: retryTimer
        interval: 3000
        onTriggered: if (root.active && !root.socket) root.start()
    }

    Timer {
        // Let the bars fall instead of freezing when playback stops.
        interval: 33
        repeat: true
        running: !root.streaming && root.values.some(v => v > 0.002)
        onTriggered: root.values = root.values.map(v => v * 0.82)
    }

    WebSocketServer {
        id: server
        host: "127.0.0.1"
        listen: true
        onUrlChanged: restartTimer.restart()
        onClientConnected: ws => {
            ws.textMessageReceived.connect(message => root.handle(ws, message));
            ws.statusChanged.connect(status => {
                if (ws === root.socket && (status === WebSocket.Closed || status === WebSocket.Error)) {
                    root.socket = null;
                    root.streaming = false;
                    // CAVA died while it should be running. Retry unless it reported an error.
                    if (root.active && !root.error) {
                        retryTimer.start();
                    }
                }
            });
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            // The bridge exited. Report a failure if it never streamed.
            if (data["exit code"] !== 0 && data["stderr"]) {
                root.error = data["stderr"].trim().split("\n").pop();
            }
            disconnectSource(source);
        }
    }

    Component.onDestruction: stop()
}
