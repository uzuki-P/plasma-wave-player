import QtQuick
import QtQml.Models
import org.kde.plasma.private.mpris as Mpris

// Picks the player to show from the real MPRIS rows.
// Plasma's multiplexer row (row 0) can keep pointing at a stale player,
// so this skips it and ranks the players itself:
//   1. a player the user picked in the popup, until another player starts playing
//   2. the playing player that started most recently
//   3. the player last picked or played, remembered across restarts
//   4. the player that was active most recently
// Players without metadata (idle browser tabs) are ignored.
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
    readonly property real volume: current?.volume ?? 0
    readonly property int shuffle: current?.shuffle ?? Mpris.ShuffleStatus.Unknown
    readonly property int loopStatus: current?.loopStatus ?? Mpris.LoopStatus.Unknown
    readonly property bool canGoNext: current?.canGoNext ?? false
    readonly property bool canGoPrevious: current?.canGoPrevious ?? false
    readonly property bool canSeek: current?.canSeek ?? false
    readonly property bool canRaise: current?.canRaise ?? false
    readonly property bool canShuffle: current !== null && current.shuffle !== Mpris.ShuffleStatus.Unknown
    readonly property bool canLoop: current !== null && current.loopStatus !== Mpris.LoopStatus.Unknown

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
    function changeVolume(delta) { current?.changeVolume(delta, true); }

    function setVolume(value) {
        if (current) {
            current.volume = value;
        }
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
        if (canShuffle) {
            current.shuffle = current.shuffle === Mpris.ShuffleStatus.On ? Mpris.ShuffleStatus.Off : Mpris.ShuffleStatus.On;
        }
    }

    function cycleLoop() {
        if (!canLoop) {
            return;
        }
        const order = [Mpris.LoopStatus.None, Mpris.LoopStatus.Playlist, Mpris.LoopStatus.Track];
        current.loopStatus = order[(order.indexOf(current.loopStatus) + 1) % order.length];
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
            refreshPosition();
        }
    }

    Mpris.Mpris2Model {
        id: mprisModel
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
