import CoreGraphics
import Vision

typealias Joint = VNHumanBodyPoseObservation.JointName

/// Counts reps from body-pose joints using joint angles with hysteresis.
/// A rep counts only after a full "down" then "up" cycle, so twitching doesn't count.
struct RepCounter {
    let kind: ChallengeKind
    private var isDown = false
    private var downFrames = 0
    private var upFrames = 0

    /// Frames a position must hold before it counts (~0.1s at 30fps), to filter jitter.
    private let holdFrames = 3

    init(kind: ChallengeKind) { self.kind = kind }

    struct Update {
        var repCompleted = false
        var bodyVisible = false
        var hint: String
    }

    /// `joints` are in pixel space of the upright image (y grows upward, as Vision returns it).
    mutating func process(_ joints: [Joint: CGPoint]) -> Update {
        switch kind {
        case .squats: return squat(joints)
        case .pushups: return pushup(joints)
        case .jumpingJacks: return jumpingJack(joints)
        default: return Update(hint: "")
        }
    }

    // MARK: Exercises

    private mutating func squat(_ j: [Joint: CGPoint]) -> Update {
        let angles = [
            angle(j[.leftHip], j[.leftKnee], j[.leftAnkle]),
            angle(j[.rightHip], j[.rightKnee], j[.rightAnkle]),
        ].compactMap { $0 }
        guard let knee = angles.min() else {
            return Update(hint: "Step back so your whole body, feet included, is in frame")
        }
        let rep = step(down: knee < 105, up: knee > 160)
        return Update(repCompleted: rep, bodyVisible: true,
                      hint: isDown ? "Now stand up tall" : "Squat down, thighs parallel to the floor")
    }

    private mutating func pushup(_ j: [Joint: CGPoint]) -> Update {
        let angles = [
            angle(j[.leftShoulder], j[.leftElbow], j[.leftWrist]),
            angle(j[.rightShoulder], j[.rightElbow], j[.rightWrist]),
        ].compactMap { $0 }
        guard let elbow = angles.min() else {
            return Update(hint: "Lean the phone on the floor facing your side so your arms are visible")
        }
        let rep = step(down: elbow < 95, up: elbow > 150)
        return Update(repCompleted: rep, bodyVisible: true,
                      hint: isDown ? "Push back up" : "Lower your chest toward the floor")
    }

    private mutating func jumpingJack(_ j: [Joint: CGPoint]) -> Update {
        guard let ls = j[.leftShoulder], let rs = j[.rightShoulder],
              let lw = j[.leftWrist], let rw = j[.rightWrist],
              let la = j[.leftAnkle], let ra = j[.rightAnkle] else {
            return Update(hint: "Step back so your whole body is in frame")
        }
        let shoulderWidth = max(abs(ls.x - rs.x), 1)
        let shoulderY = max(ls.y, rs.y)
        let feetApart = abs(la.x - ra.x) > shoulderWidth * 1.3
        let armsUp = lw.y > shoulderY && rw.y > shoulderY
        let armsDown = lw.y < min(ls.y, rs.y) && rw.y < min(ls.y, rs.y)
        let feetTogether = abs(la.x - ra.x) < shoulderWidth * 1.1

        // "down" here means the open star position; a rep completes on returning to closed.
        let rep = step(down: armsUp && feetApart, up: armsDown && feetTogether)
        return Update(repCompleted: rep, bodyVisible: true,
                      hint: isDown ? "Back together" : "Jump out: arms up, feet wide")
    }

    // MARK: Helpers

    private mutating func step(down: Bool, up: Bool) -> Bool {
        downFrames = down ? downFrames + 1 : 0
        upFrames = up ? upFrames + 1 : 0
        if !isDown && downFrames >= holdFrames {
            isDown = true
        } else if isDown && upFrames >= holdFrames {
            isDown = false
            return true
        }
        return false
    }

    /// Angle at `b` (degrees) formed by a-b-c.
    private func angle(_ a: CGPoint?, _ b: CGPoint?, _ c: CGPoint?) -> CGFloat? {
        guard let a, let b, let c else { return nil }
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
        guard mag > 0 else { return nil }
        return acos(max(-1, min(1, dot / mag))) * 180 / .pi
    }
}
