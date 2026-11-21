import Foundation
import ManagedSettings

/// What a completed challenge unlocks.
enum UnlockTarget: Codable, Hashable {
    case app(ApplicationToken)
    case web(WebDomainToken)
    /// Unlock every blocked app & site ("take a break").
    case everything

    var appToken: ApplicationToken? {
        if case .app(let t) = self { return t }
        return nil
    }

    var webToken: WebDomainToken? {
        if case .web(let t) = self { return t }
        return nil
    }
}

/// A time-limited unlock the user has earned.
struct ActiveUnlock: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var target: UnlockTarget
    var expires: Date
    var started: Date = Date()

    var isActive: Bool { expires > Date() }
}

/// Created by the shield's "Unlock" button so the main app knows what to unlock.
struct PendingUnlock: Codable, Hashable {
    var target: UnlockTarget
    var requested: Date = Date()

    /// Requests go stale so an old tap doesn't hijack the app later.
    var isFresh: Bool { Date().timeIntervalSince(requested) < 15 * 60 }
}

enum ChallengeKind: String, Codable, CaseIterable, Identifiable {
    case photo, squats, pushups, jumpingJacks, steps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: "Photo hunt"
        case .squats: "Squats"
        case .pushups: "Push-ups"
        case .jumpingJacks: "Jumping jacks"
        case .steps: "Go for a walk"
        }
    }

    var systemImage: String {
        switch self {
        case .photo: "camera.viewfinder"
        case .squats: "figure.strengthtraining.functional"
        case .pushups: "figure.core.training"
        case .jumpingJacks: "figure.mixed.cardio"
        case .steps: "figure.walk"
        }
    }

    var unit: String {
        switch self {
        case .photo: "photos"
        case .steps: "steps"
        default: "reps"
        }
    }

    /// Default amount for a 5-minute unlock, before multipliers.
    var defaultBase: Int {
        switch self {
        case .photo: 1
        case .squats: 10
        case .pushups: 5
        case .jumpingJacks: 15
        case .steps: 150
        }
    }

    /// How much each earlier unlock today adds (escalation).
    var escalationStep: Int {
        switch self {
        case .photo: 0
        case .squats: 2
        case .pushups: 1
        case .jumpingJacks: 3
        case .steps: 30
        }
    }

    var isExercise: Bool { self == .squats || self == .pushups || self == .jumpingJacks }
}

enum UnlockDuration: Int, Codable, CaseIterable, Identifiable {
    case five = 5, fifteen = 15, thirty = 30, sixty = 60

    var id: Int { rawValue }
    var minutes: Int { rawValue }
    var label: String { rawValue == 60 ? "1 hour" : "\(rawValue) min" }

    /// Longer unlocks cost more effort.
    var multiplier: Double {
        switch self {
        case .five: 1
        case .fifteen: 2
        case .thirty: 3
        case .sixty: 5
        }
    }

    /// Photo challenges scale by number of distinct photos instead.
    var photoCount: Int {
        switch self {
        case .five, .fifteen: 1
        case .thirty: 2
        case .sixty: 3
        }
    }
}

struct DailyStats: Codable, Hashable {
    var day: String = DailyStats.today()
    var unlocks: Int = 0
    var reps: Int = 0
    var steps: Int = 0
    var photos: Int = 0
    var minutesEarned: Int = 0

    static func today() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

struct LifetimeStats: Codable, Hashable {
    var unlocks: Int = 0
    var reps: Int = 0
    var steps: Int = 0
    var photos: Int = 0
    var resisted: Int = 0   // times the user hit "Close" on the shield
}
