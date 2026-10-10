import QtQuick

// Draws CAVA values as a filled wave or rounded bars.
// The part left of `progress` uses `playedAlpha`, so the visualizer
// doubles as the track progress bar.
Canvas {
    id: canvas

    property var values: []
    property int style: 0 // 0: wave, 1: bars
    property bool rainbow: false
    property color color: "steelblue"
    property real progress: -1 // 0..1, negative hides the split
    property real playedAlpha: 0.55
    property real restAlpha: 0.22
    property real lineAlpha: 0.9
    property real lineWidth: 1.5
    property real radius: 0
    property real heightRatio: 0.9
    // Keeps a strip visible during silence so progress still shows.
    property real floor: 0

    onValuesChanged: requestPaint()
    onProgressChanged: requestPaint()
    onColorChanged: requestPaint()
    onRainbowChanged: requestPaint()
    onStyleChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function strokeFor(ctx) {
        if (!rainbow) {
            return color;
        }
        const gradient = ctx.createLinearGradient(0, 0, width, 0);
        for (let i = 0; i <= 6; i++) {
            gradient.addColorStop(i / 6, Qt.hsla(i / 6, 0.8, 0.62, 1));
        }
        return gradient;
    }

    function tracePath(ctx, ys, close) {
        const n = ys.length;
        const step = width / (n - 1);
        ctx.beginPath();
        ctx.moveTo(0, ys[0]);
        for (let i = 1; i < n; i++) {
            const x = i * step;
            const px = (i - 1) * step;
            if (i === n - 1) {
                ctx.quadraticCurveTo(px, ys[i - 1], x, ys[i]);
            } else {
                ctx.quadraticCurveTo(px, ys[i - 1], (px + x) / 2, (ys[i - 1] + ys[i]) / 2);
            }
        }
        if (close) {
            ctx.lineTo(width, height);
            ctx.lineTo(0, height);
            ctx.closePath();
        }
    }

    function paintRegions(ctx, painter) {
        const split = progress < 0 ? width : Math.max(0, Math.min(1, progress)) * width;
        ctx.save();
        ctx.beginPath();
        ctx.rect(0, 0, split, height);
        ctx.clip();
        ctx.globalAlpha = playedAlpha;
        painter();
        ctx.restore();
        if (split < width) {
            ctx.save();
            ctx.beginPath();
            ctx.rect(split, 0, width - split, height);
            ctx.clip();
            ctx.globalAlpha = restAlpha;
            painter();
            ctx.restore();
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const n = values.length;
        if (width <= 0 || height <= 0 || (n < 2 && floor <= 0)) {
            return;
        }
        if (radius > 0) {
            ctx.beginPath();
            ctx.roundedRect(0, 0, width, height, radius, radius);
            ctx.clip();
        }
        const paint = strokeFor(ctx);
        const data = n < 2 ? [0, 0] : values;
        const count = data.length;
        const usable = height * heightRatio - floor;

        if (style === 1) {
            const slot = width / count;
            const barWidth = Math.max(2, slot * 0.55);
            ctx.lineCap = "round";
            ctx.lineWidth = barWidth;
            ctx.strokeStyle = paint;
            paintRegions(ctx, () => {
                ctx.beginPath();
                for (let i = 0; i < count; i++) {
                    const x = slot * (i + 0.5);
                    const half = Math.max(0.5, data[i] * (usable - barWidth) / 2);
                    ctx.moveTo(x, height / 2 - half);
                    ctx.lineTo(x, height / 2 + half);
                }
                ctx.stroke();
            });
            return;
        }

        const ys = data.map(v => height - floor - Math.min(1, v) * usable - lineWidth / 2);
        ctx.fillStyle = paint;
        paintRegions(ctx, () => {
            tracePath(ctx, ys, true);
            ctx.fill();
        });
        ctx.globalAlpha = lineAlpha;
        ctx.strokeStyle = paint;
        ctx.lineWidth = lineWidth;
        tracePath(ctx, ys, false);
        ctx.stroke();
    }
}
