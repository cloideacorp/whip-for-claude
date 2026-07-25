import Foundation
import CoreGraphics
import QuartzCore

struct WhipPoint {
    var x: CGFloat
    var y: CGFloat
    var px: CGFloat
    var py: CGFloat
}

struct WhipPhysics {
    var segments = 28
    var segmentLength: CGFloat = 25
    var taper: CGFloat = 0.6
    var gravity: CGFloat = 1.2
    var dropGravity: CGFloat = 0.95
    var damping: CGFloat = 0.96
    var constraintIters = 20
    var maxStretchRatio: CGFloat = 1.2
    var baseTargetAngle: CGFloat = -1.12
    var handleAimByMouseX: CGFloat = 0.4
    var handleAimByMouseY: CGFloat = 0.2
    var handleAimClamp: CGFloat = 2.0
    var handleSpring: CGFloat = 0.7
    var handleAngularDamping: CGFloat = 0.078
    var basePoseSegments = 2
    var basePoseStiffStart: CGFloat = 0.9
    var basePoseStiffEnd: CGFloat = 0.8
    var handleMaxBendDeg: CGFloat = 16
    var tipMaxBendDeg: CGFloat = 130
    var bendRigidityStart: CGFloat = 0.8
    var bendRigidityEnd: CGFloat = 0.12
    var wallBounce: CGFloat = 0.42
    var wallFriction: CGFloat = 0.86
    var crackSpeed: CGFloat = 340
    var crackCooldownMs: CFTimeInterval = 0.2
    var firstCrackGraceMs: CFTimeInterval = 0.35
    var arcWidth: CGFloat = 260
    var arcHeight: CGFloat = 185

    var points: [WhipPoint] = []
    var dropping = false
    var handleAngle: CGFloat = -1.12
    var handleAngVel: CGFloat = 0
    private var lastCrack: CFTimeInterval = 0
    private var spawnTime: CFTimeInterval = 0
    private var prevMouse = CGPoint.zero

    mutating func spawn(at mouse: CGPoint) {
        dropping = false
        lastCrack = 0
        spawnTime = CACurrentMediaTime()
        handleAngle = baseTargetAngle
        handleAngVel = 0
        prevMouse = mouse
        points = (0..<segments).map { i in
            let t = CGFloat(i) / CGFloat(segments - 1)
            let x = mouse.x + t * arcWidth
            let y = mouse.y - sin(t * .pi * 0.75) * arcHeight
            return WhipPoint(x: x, y: y, px: x, py: y)
        }
    }

    mutating func drop() {
        if !points.isEmpty && !dropping { dropping = true }
    }

    private func segLen(_ i: Int) -> CGFloat {
        let t = CGFloat(i) / CGFloat(segments - 1)
        return segmentLength * (1 - t * (1 - taper))
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func wrapPi(_ a: CGFloat) -> CGFloat {
        var v = a
        while v > .pi { v -= .pi * 2 }
        while v < -.pi { v += .pi * 2 }
        return v
    }

    mutating func update(mouse: CGPoint, bounds: CGSize) -> Bool {
        guard !points.isEmpty else { return false }

        if !dropping {
            let mvx = mouse.x - prevMouse.x
            let mvy = mouse.y - prevMouse.y
            let delta = clamp(mvx * handleAimByMouseX + mvy * handleAimByMouseY, -handleAimClamp, handleAimClamp)
            let target = baseTargetAngle + delta
            let err = wrapPi(target - handleAngle)
            handleAngVel += err * handleSpring
            handleAngVel *= handleAngularDamping
            handleAngle = wrapPi(handleAngle + handleAngVel)
        }

        let g = dropping ? dropGravity : gravity
        let start = dropping ? 0 : 1
        for i in start..<points.count {
            let vx = (points[i].x - points[i].px) * damping
            let vy = (points[i].y - points[i].py) * damping
            points[i].px = points[i].x
            points[i].py = points[i].y
            points[i].x += vx
            points[i].y += vy + g
        }

        if !dropping {
            points[0].x = mouse.x
            points[0].y = mouse.y
            points[0].px = mouse.x
            points[0].py = mouse.y
        }

        for _ in 0..<constraintIters {
            for i in 0..<(points.count - 1) {
                let dx = points[i + 1].x - points[i].x
                let dy = points[i + 1].y - points[i].y
                let dist = max(hypot(dx, dy), 0.0001)
                let target = segLen(i)
                let diff = (dist - target) / dist * 0.5
                let ox = dx * diff
                let oy = dy * diff
                if i == 0 && !dropping {
                    points[i + 1].x -= ox * 2
                    points[i + 1].y -= oy * 2
                } else {
                    points[i].x += ox
                    points[i].y += oy
                    points[i + 1].x -= ox
                    points[i + 1].y -= oy
                }
            }
            applyBendLimits()
            if !dropping { applyBasePose() }
            capStretch()
            applyWalls(bounds)
        }

        var cracked = false
        let tip = points[points.count - 1]
        let tipVel = hypot(tip.x - tip.px, tip.y - tip.py)
        let now = CACurrentMediaTime()
        if !dropping && tipVel > crackSpeed {
            if now - spawnTime >= firstCrackGraceMs && now - lastCrack > crackCooldownMs {
                lastCrack = now
                cracked = true
            }
        }

        if dropping && points.allSatisfy({ $0.y > bounds.height + 60 }) {
            points.removeAll()
            dropping = false
        }

        prevMouse = mouse
        return cracked
    }

    private mutating func applyBasePose() {
        guard !points.isEmpty, !dropping else { return }
        let dx = cos(handleAngle)
        let dy = sin(handleAngle)
        let guided = min(basePoseSegments, points.count - 1)
        for i in 1...guided {
            let t = CGFloat(i - 1) / CGFloat(max(guided - 1, 1))
            let stiff = lerp(basePoseStiffStart, basePoseStiffEnd, t)
            let prev = points[i - 1]
            let targetLen = segLen(i - 1)
            points[i].x = lerp(points[i].x, prev.x + dx * targetLen, stiff)
            points[i].y = lerp(points[i].y, prev.y + dy * targetLen, stiff)
        }
    }

    private mutating func applyBendLimits() {
        guard points.count >= 3 else { return }
        for i in 1..<(points.count - 1) {
            let a = points[i - 1], b = points[i], c = points[i + 1]
            let v1x = a.x - b.x, v1y = a.y - b.y
            let v2x = c.x - b.x, v2y = c.y - b.y
            let l1 = max(hypot(v1x, v1y), 0.0001)
            let l2 = max(hypot(v2x, v2y), 0.0001)
            let n1x = v1x / l1, n1y = v1y / l1
            let n2x = v2x / l2, n2y = v2y / l2
            let dot = clamp(n1x * n2x + n1y * n2y, -1, 1)
            let angle = acos(dot)
            let t = CGFloat(i) / CGFloat(points.count - 2)
            let maxBend = lerp(handleMaxBendDeg, tipMaxBendDeg, t) * .pi / 180
            let bend = .pi - angle
            guard bend > maxBend else { continue }
            let cross = n1x * n2y - n1y * n2x
            let sign: CGFloat = cross >= 0 ? 1 : -1
            let targetA = atan2(n1y, n1x) + sign * (.pi - maxBend)
            let rigidity = lerp(bendRigidityStart, bendRigidityEnd, t)
            points[i + 1].x = lerp(c.x, b.x + cos(targetA) * l2, rigidity)
            points[i + 1].y = lerp(c.y, b.y + sin(targetA) * l2, rigidity)
        }
    }

    private mutating func capStretch() {
        for i in 0..<(points.count - 1) {
            let dx = points[i + 1].x - points[i].x
            let dy = points[i + 1].y - points[i].y
            let dist = max(hypot(dx, dy), 0.0001)
            let maxLen = segLen(i) * maxStretchRatio
            guard dist > maxLen else { continue }
            let k = maxLen / dist
            points[i + 1].x = points[i].x + dx * k
            points[i + 1].y = points[i].y + dy * k
        }
    }

    private mutating func applyWalls(_ bounds: CGSize) {
        guard !dropping else { return }
        for i in 1..<points.count {
            var vx = points[i].x - points[i].px
            var vy = points[i].y - points[i].py
            var hit = false
            if points[i].x < 0 {
                points[i].x = 0
                if vx < 0 { vx = -vx * wallBounce }
                vy *= wallFriction
                hit = true
            } else if points[i].x > bounds.width {
                points[i].x = bounds.width
                if vx > 0 { vx = -vx * wallBounce }
                vy *= wallFriction
                hit = true
            }
            if points[i].y < 0 {
                points[i].y = 0
                if vy < 0 { vy = -vy * wallBounce }
                vx *= wallFriction
                hit = true
            } else if points[i].y > bounds.height {
                points[i].y = bounds.height
                if vy > 0 { vy = -vy * wallBounce }
                vx *= wallFriction
                hit = true
            }
            if hit {
                points[i].px = points[i].x - vx
                points[i].py = points[i].y - vy
            }
        }
    }
}
