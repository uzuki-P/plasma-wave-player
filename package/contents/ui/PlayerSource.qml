import QtQuick
import QtQml.Models
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.workspace.dbus as DBus

// Picks the player to show from the real MPRIS rows.
// Plasma's multiplexer row (row 0) can keep pointing at a stale player,
// so this skips it and ranks the players itself:
//   1. a player the user picked in the popup, until another player starts playing
//   2. the playing player that started most recently
//   3. the player last picked or played, remembered across restarts
//   4. the player that was active most recently
// Players without metadata (idle browser tabs) are ignored.
//
// Some players (Metrolist) never emit PropertiesChanged for Volume, Shuffle
// and LoopStatus, so the container keeps the values it read at startup and
// its setters skip writes that match that stale cache. This polls those three
// properties over D-Bus and writes shuffle and repeat directly.
Item {
    id: root

    property var current: null
    property var players: []
    property var manual: null
    // Identity of the player last picked or played. main.qml persists it.
    property string preferredIdentity: ""

    readonly property bool ready: current !== null
    readonly property string title: current?.track ?? ""
    readonly property string artist: current?.artist ?? ""
    readonly property string album: current?.album ?? ""
    readonly property string artUrl: current?.artUrl ?? ""
    readonly property string identity: current?.identity ?? ""
    readonly property string iconName: current?.iconName ?? "view-media-track"
    readonly property int playbackStatus: current?.playbackStatus ?? Mpris.PlaybackStatus.Unknown
    readonly property bool playing: playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property real length: current?.length ?? 0
    readonly property real volume: current ? liveVolume : 0
    readonly property int shuffle: current ? liveShuffle : Mpris.ShuffleStatus.Unknown
    readonly property int loopStatus: current ? liveLoopStatus : Mpris.LoopStatus.Unknown
    readonly property bool canGoNext: current?.canGoNext ?? false
    readonly property bool canGoPrevious: current?.canGoPrevious ?? false
    readonly property bool canSeek: current?.canSeek ?? false
    readonly property bool canRaise: current?.canRaise ?? false
    readonly property bool canShuffle: current !== null && shuffle !== Mpris.ShuffleStatus.Unknown
    readonly property bool canLoop: current !== null && loopStatus !== Mpris.LoopStatus.Unknown

    // Poll faster while the popup is open.
    property bool fastPoll: false

    // Last known values, from the container, a poll, or our own write.
    property real liveVolume: 0
    property int liveShuffle: Mpris.ShuffleStatus.Unknown
    property int liveLoopStatus: Mpris.LoopStatus.Unknown
    // D-Bus name of the current player, resolved from its PID.
    property string service: ""
    // Bumped on every write so replies to polls sent before it are dropped.
    property int writeSerial: 0

    // MPRIS only reports position on seek, so poll it and interpolate between polls.
    property real position: 0
    property real positionBase: 0
    property double positionStamp: 0

    function refreshPosition() {
        if (!current) {
            positionBase = 0;
            position = 0;
            return;
        }
        current.updatePosition();
        syncPosition();
    }

    function syncPosition() {
        positionBase = current?.position ?? 0;
        positionStamp = Date.now();
        position = positionBase;
    }

    function tickPosition() {
        if (!current) {
            return;
        }
        const rate = current.rate || 1;
        position = Math.min(length, positionBase + (Date.now() - positionStamp) * 1000 * rate);
    }

    function playPause() { current?.PlayPause(); }
    function next() { current?.Next(); }
    function previous() { current?.Previous(); }
    function raise() { current?.Raise(); }
    function changeVolume(delta) { setVolume(volume + delta, true); }

    // The container's volume setter skips values equal to its stale cache,
    // and QML sends whole numbers as int32, so go through changeVolume(),
    // which always writes a double and updates the cache.
    function setVolume(value, showOSD) {
        if (!current) {
            return;
        }
        value = Math.max(0, Math.min(1, value));
        current.changeVolume(value - current.volume, showOSD === true);
        noteWrite();
        liveVolume = value;
    }

    function seek(microseconds) {
        if (current) {
            current.position = microseconds;
            positionBase = microseconds;
            positionStamp = Date.now();
            position = microseconds;
        }
    }

    function toggleShuffle() {
        if (!canShuffle) {
            return;
        }
        const on = shuffle !== Mpris.ShuffleStatus.On;
        if (!writeProperty("Shuffle", on)) {
            current.shuffle = on ? Mpris.ShuffleStatus.On : Mpris.ShuffleStatus.Off;
        }
        liveShuffle = on ? Mpris.ShuffleStatus.On : Mpris.ShuffleStatus.Off;
    }

    function cycleLoop() {
        if (!canLoop) {
            return;
        }
        const order = [Mpris.LoopStatus.None, Mpris.LoopStatus.Playlist, Mpris.LoopStatus.Track];
        const next = order[(order.indexOf(loopStatus) + 1) % order.length];
        if (!writeProperty("LoopStatus", loopNames[next])) {
            current.loopStatus = next;
        }
        liveLoopStatus = next;
    }

    readonly property var loopNames: ({
        [Mpris.LoopStatus.None]: "None",
        [Mpris.LoopStatus.Playlist]: "Playlist",
        [Mpris.LoopStatus.Track]: "Track"
    })

    function busCall(service, path, iface, member, args) {
        return DBus.SessionBus.asyncCall({
            service: service,
            path: path,
            iface: iface,
            member: member,
            arguments: args.map(a => typeof a === "string" ? new DBus.string(a) : a),
            signature: args.length ? "(" + args.map(a => typeof a === "string" ? "s" : "v").join("") + ")" : ""
        });
    }

    function noteWrite() {
        writeSerial++;
        confirmTimer.restart();
    }

    // Returns false when the player's D-Bus name is unknown.
    function writeProperty(name, value) {
        if (!service) {
            return false;
        }
        busCall(service, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "Set",
            ["org.mpris.MediaPlayer2.Player", name, new DBus.variant(value)]);
        noteWrite();
        return true;
    }

    function resetLive() {
        liveVolume = current?.volume ?? 0;
        liveShuffle = current?.shuffle ?? Mpris.ShuffleStatus.Unknown;
        liveLoopStatus = current?.loopStatus ?? Mpris.LoopStatus.Unknown;
    }

    function resolveService() {
        service = "";
        const target = current;
        if (!target) {
            return;
        }
        const names = busCall("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ListNames", []);
        names.finished.connect(() => {
            if (names.isError || target !== current) {
                return;
            }
            for (const name of names.value.filter(n => n.startsWith("org.mpris.MediaPlayer2."))) {
                const pid = busCall("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID", [name]);
                pid.finished.connect(() => {
                    if (!pid.isError && !service && target === current && Number(pid.value) === Number(target.instancePid)) {
                        service = name;
                        poll();
                    }
                });
            }
        });
    }

    function poll() {
        if (!service) {
            return;
        }
        const serial = writeSerial;
        const target = current;
        const reply = busCall(service, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "GetAll", ["org.mpris.MediaPlayer2.Player"]);
        reply.finished.connect(() => {
            if (reply.isError || serial !== writeSerial || target !== current) {
                return;
            }
            // Some values come back wrapped as {value: ...}.
            const unwrap = v => v !== null && typeof v === "object" && "value" in v ? v.value : v;
            const props = reply.value;
            if (props.Volume !== undefined) {
                liveVolume = Number(unwrap(props.Volume));
            }
            if (props.Shuffle !== undefined) {
                liveShuffle = unwrap(props.Shuffle) === true ? Mpris.ShuffleStatus.On : Mpris.ShuffleStatus.Off;
            }
            const loop = Object.keys(loopNames).find(k => loopNames[k] === unwrap(props.LoopStatus));
            if (loop !== undefined) {
                liveLoopStatus = Number(loop);
            }
        });
    }

    function pick(container) {
        manual = container;
        preferredIdentity = container.identity;
        select();
    }

    function select() {
        const list = [];
        let best = null;
        let bestScore = -1;
        let manualAlive = false;
        for (let i = 0; i < instantiator.count; i++) {
            const entry = instantiator.objectAt(i);
            if (!entry || entry.isMultiplexer || !entry.container) {
                continue;
            }
            const c = entry.container;
            if (!(c.track || c.artist || c.album)) {
                continue;
            }
            list.push(c);
            if (c === manual) {
                manualAlive = true;
            }
            const score = (c.playbackStatus === Mpris.PlaybackStatus.Playing ? 4e13 : 0)
                + (c.identity === preferredIdentity ? 2e13 : 0)
                + entry.lastActive;
            if (score > bestScore) {
                best = c;
                bestScore = score;
            }
        }
        if (!manualAlive) {
            manual = null;
        }
        players = list;
        const next = manual ?? best;
        if (next !== current) {
            current = next;
            resetLive();
            resolveService();
            refreshPosition();
        }
    }

    Mpris.Mpris2Model {
        id: mprisModel
    }

    // Players that do emit changes still update right away.
    Connections {
        target: root.current
        ignoreUnknownSignals: true
        function onVolumeChanged() { root.liveVolume = root.current.volume; }
        function onShuffleChanged() { root.liveShuffle = root.current.shuffle; }
        function onLoopStatusChanged() { root.liveLoopStatus = root.current.loopStatus; }
    }

    Instantiator {
        id: instantiator
        model: mprisModel
        delegate: QtObject {
            required property var container
            required property bool isMultiplexer
            property double lastActive: container?.playbackStatus === Mpris.PlaybackStatus.Playing ? Date.now() : 0

            property Connections watcher: Connections {
                target: isMultiplexer ? null : container
                ignoreUnknownSignals: true

                function onPlaybackStatusChanged() {
                    lastActive = Date.now();
                    if (container.playbackStatus === Mpris.PlaybackStatus.Playing) {
                        root.preferredIdentity = container.identity;
                        if (root.manual !== container) {
                            root.manual = null;
                        }
                    }
                    Qt.callLater(root.select);
                }
                function onTrackChanged() {
                    lastActive = Date.now();
                    Qt.callLater(root.select);
                    if (container === root.current) {
                        Qt.callLater(root.refreshPosition);
                    }
                }
                function onArtistChanged() { Qt.callLater(root.select); }
                function onPositionChanged() {
                    // updatePosition() answers asynchronously through this signal.
                    if (container === root.current) {
                        root.syncPosition();
                    }
                }
            }
        }
        onObjectAdded: Qt.callLater(root.select)
        onObjectRemoved: Qt.callLater(root.select)
    }

    Timer {
        // Catches players that change state without a signal we listen to.
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.select()
    }

    Timer {
        interval: root.fastPoll ? 1000 : 3000
        running: root.service !== ""
        repeat: true
        onTriggered: root.poll()
    }

    Timer {
        // Reads back what the player settled on after our write.
        id: confirmTimer
        interval: 400
        onTriggered: root.poll()
    }

    Timer {
        interval: 2000
        running: root.playing
        repeat: true
        onTriggered: root.refreshPosition()
    }

    Timer {
        interval: 250
        running: root.playing
        repeat: true
        onTriggered: root.tickPosition()
    }

    onPlayingChanged: refreshPosition()
}
