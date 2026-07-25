import AppKit
import AVFoundation

final class WhipView: NSView {
    var physics = WhipPhysics()
    var onCrack: (() -> Void)?
    var onFallen: (() -> Void)?

    private var displayLink: CVDisplayLink?
    private var mouse = CGPoint.zero
    private let sounds = ["A", "B", "C", "D", "E"]
    private var players: [AVAudioPlayer] = []

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.011).cgColor
        preloadSounds()
        startDisplayLink()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopDisplayLink()
    }

    func spawn() {
        if let win = window {
            let local = convert(win.mouseLocationOutsideOfEventStream, from: nil)
            mouse = CGPoint(x: local.x, y: local.y)
        } else {
            mouse = CGPoint(x: bounds.midX, y: bounds.midY)
        }
        hadPoints = true
        physics.spawn(at: mouse)
        needsDisplay = true
    }

    func drop() {
        physics.drop()
    }

    private func preloadSounds() {
        for name in sounds {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "sounds"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                players.append(player)
            }
        }
    }

    private func playCrack() {
        guard let p = players.randomElement() else { return }
        p.currentTime = 0
        p.play()
    }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        mouse = CGPoint(x: p.x, y: p.y)
    }

    override func mouseDown(with event: NSEvent) {
        physics.drop()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    private var hadPoints = false

    private func tick() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let win = self.window {
                let local = self.convert(win.mouseLocationOutsideOfEventStream, from: nil)
                self.mouse = CGPoint(x: local.x, y: local.y)
            }
            let cracked = self.physics.update(mouse: self.mouse, bounds: self.bounds.size)
            if cracked {
                self.playCrack()
                self.onCrack?()
            }
            self.needsDisplay = true
            let hasPoints = !self.physics.points.isEmpty
            if self.hadPoints && !hasPoints {
                self.onFallen?()
            }
            self.hadPoints = hasPoints
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !physics.points.isEmpty else { return }
        let pts = physics.points
        guard pts.count >= 2 else { return }

        let path = NSBezierPath()
        path.move(to: NSPoint(x: pts[0].x, y: pts[0].y))
        for i in 0..<(pts.count - 1) {
            let p0 = catmull(pts, i - 1)
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = catmull(pts, i + 2)
            path.curve(
                to: NSPoint(x: p2.x, y: p2.y),
                controlPoint1: NSPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                controlPoint2: NSPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            )
        }

        NSColor.white.setStroke()
        path.lineWidth = 11
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()

        NSColor(white: 0.07, alpha: 1).setStroke()
        path.lineWidth = 6
        path.stroke()
    }

    private func catmull(_ pts: [WhipPoint], _ i: Int) -> WhipPoint {
        let n = pts.count
        if i < 0 {
            if n >= 2 {
                return WhipPoint(x: 2 * pts[0].x - pts[1].x, y: 2 * pts[0].y - pts[1].y, px: 0, py: 0)
            }
            return pts[0]
        }
        if i >= n {
            if n >= 2 {
                let a = pts[n - 2], b = pts[n - 1]
                return WhipPoint(x: 2 * b.x - a.x, y: 2 * b.y - a.y, px: 0, py: 0)
            }
            return pts[n - 1]
        }
        return pts[i]
    }

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        displayLink = link
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, ctx -> CVReturn in
            let view = Unmanaged<WhipView>.fromOpaque(ctx!).takeUnretainedValue()
            view.tick()
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
    }
}
