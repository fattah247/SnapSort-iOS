//
//  HapticPattern.swift
//  SnapSort
//
//  The app's haptic vocabulary. Each pattern belongs to one kind of action so
//  people learn what it means. Patterns are plain data, so they can be tested
//  and tuned without a device.
//
//  Sharpness and weight follow the visuals: bookmarking (honey) is bright and
//  crisp, trashing (tomato) is round and heavy. Patterns played on every swipe
//  stay short and moderate; only rare moments get anything longer.
//

import Foundation

struct HapticEvent: Equatable {
    enum Kind: Equatable {
        /// A single tap
        case tap
        /// A short sustained vibration whose intensity moves from the event's
        /// `intensity` to `endIntensity` over `duration`
        case continuous(duration: TimeInterval, endIntensity: Float)
    }

    /// Seconds from the start of the pattern
    let time: TimeInterval
    let kind: Kind
    let intensity: Float
    /// Low is round and soft, high is crisp and mechanical
    let sharpness: Float

    static func tap(at time: TimeInterval, intensity: Float, sharpness: Float) -> HapticEvent {
        HapticEvent(time: time, kind: .tap, intensity: intensity, sharpness: sharpness)
    }

    static func continuous(
        at time: TimeInterval,
        duration: TimeInterval,
        from intensity: Float,
        to endIntensity: Float,
        sharpness: Float
    ) -> HapticEvent {
        HapticEvent(
            time: time,
            kind: .continuous(duration: duration, endIntensity: endIntensity),
            intensity: intensity,
            sharpness: sharpness
        )
    }

    var endTime: TimeInterval {
        if case .continuous(let duration, _) = kind { return time + duration }
        return time
    }

    var peakIntensity: Float {
        if case .continuous(_, let end) = kind { return max(intensity, end) }
        return intensity
    }

    func delayed(by offset: TimeInterval) -> HapticEvent {
        HapticEvent(time: time + offset, kind: kind, intensity: intensity, sharpness: sharpness)
    }
}

/// What plays on devices without Core Haptics
enum HapticFallback: Equatable {
    enum ImpactWeight: Hashable {
        case light, medium, soft, rigid
    }

    case impact(ImpactWeight, intensity: Float)
    case selection
    case success
    case error
}

enum HapticPattern: Hashable {
    /// The drag crossed into a swipe zone
    case detent(SwipeDirection)
    /// The drag left a swipe zone, or a bookmark was removed
    case release
    case bookmark
    case trash
    case skip
    case undo
    /// Several photos went to the trash at once
    case bulkTrash(count: Int)
    case confirm
    case restore
    /// Key-down on a chunky button
    case press
    /// A milestone or session goal
    case celebrate
    /// Standard iOS feedback, used where its documented meaning fits
    case system(SystemFeedback)

    enum SystemFeedback: Hashable {
        case selection, success, error
    }

    /// Bulk patterns with more photos than the cascade shows are the same pattern
    var normalized: HapticPattern {
        if case .bulkTrash(let count) = self {
            return .bulkTrash(count: min(max(count, 1), Constants.Haptics.maxCascadeTicks))
        }
        return self
    }

    var events: [HapticEvent] {
        switch self {
        case .detent(.right):
            return [.tap(at: 0, intensity: 0.55, sharpness: 0.75)]
        case .detent(.left):
            return [.tap(at: 0, intensity: 0.55, sharpness: 0.40)]
        case .release:
            return [.tap(at: 0, intensity: 0.28, sharpness: 0.30)]
        case .bookmark:
            // Rising "ding-ding"
            return [
                .tap(at: 0, intensity: 0.50, sharpness: 0.70),
                .tap(at: 0.07, intensity: 0.75, sharpness: 0.90)
            ]
        case .trash:
            // A weighty thunk that settles, like something landing in a bin
            return [
                .tap(at: 0, intensity: 0.75, sharpness: 0.30),
                .continuous(at: 0.01, duration: 0.09, from: 0.35, to: 0, sharpness: 0.10)
            ]
        case .skip:
            return [.tap(at: 0, intensity: 0.35, sharpness: 0.50)]
        case .undo:
            // Falling — the reverse of bookmarking
            return [
                .tap(at: 0, intensity: 0.60, sharpness: 0.60),
                .tap(at: 0.06, intensity: 0.35, sharpness: 0.40)
            ]
        case .bulkTrash(let count):
            // One tick per photo, then the trash thunk
            let ticks = min(max(count, 1), Constants.Haptics.maxCascadeTicks)
            let spacing = 0.045
            let cascade = (0..<ticks).map { index -> HapticEvent in
                let rise = ticks > 1 ? Float(index) / Float(ticks - 1) : 0
                return .tap(at: Double(index) * spacing, intensity: 0.25 + 0.15 * rise, sharpness: 0.65)
            }
            let landing = Double(ticks) * spacing
            return cascade + HapticPattern.trash.events.map { $0.delayed(by: landing) }
        case .confirm:
            return [.tap(at: 0, intensity: 0.45, sharpness: 0.55)]
        case .restore:
            // A small swell, then it pops back into place
            return [
                .continuous(at: 0, duration: 0.05, from: 0.05, to: 0.35, sharpness: 0.40),
                .tap(at: 0.055, intensity: 0.55, sharpness: 0.70)
            ]
        case .press:
            return [.tap(at: 0, intensity: 0.32, sharpness: 0.35)]
        case .celebrate:
            // A rising fanfare, then sparkles that fade with the confetti burst
            return [
                .tap(at: 0, intensity: 0.45, sharpness: 0.50),
                .tap(at: 0.09, intensity: 0.65, sharpness: 0.70),
                .tap(at: 0.18, intensity: 0.90, sharpness: 0.90),
                .tap(at: 0.28, intensity: 0.30, sharpness: 0.95),
                .tap(at: 0.36, intensity: 0.22, sharpness: 0.95),
                .tap(at: 0.46, intensity: 0.15, sharpness: 0.95),
                .tap(at: 0.58, intensity: 0.10, sharpness: 0.95)
            ]
        case .system:
            return []
        }
    }

    var duration: TimeInterval {
        events.map(\.endTime).max() ?? 0
    }

    var peakIntensity: Float {
        events.map(\.peakIntensity).max() ?? 0
    }

    /// True for standard iOS feedback, which always plays through UIKit
    var isSystem: Bool {
        if case .system = self { return true }
        return false
    }

    var fallback: HapticFallback {
        switch self {
        case .detent(.right): return .impact(.rigid, intensity: 0.6)
        case .detent(.left): return .impact(.soft, intensity: 0.7)
        case .release: return .impact(.soft, intensity: 0.35)
        case .bookmark: return .impact(.rigid, intensity: 0.7)
        case .trash, .bulkTrash: return .impact(.medium, intensity: 0.8)
        case .skip: return .impact(.light, intensity: 0.5)
        case .undo: return .impact(.light, intensity: 0.6)
        case .confirm: return .impact(.light, intensity: 0.6)
        case .restore: return .impact(.light, intensity: 0.7)
        case .press: return .impact(.soft, intensity: 0.45)
        case .celebrate, .system(.success): return .success
        case .system(.selection): return .selection
        case .system(.error): return .error
        }
    }

    /// Every pattern, for the Haptics Lab and tests
    static let all: [HapticPattern] = [
        .detent(.right), .detent(.left), .release, .bookmark, .trash, .skip, .undo,
        .bulkTrash(count: 1), .bulkTrash(count: 4), .confirm, .restore, .press, .celebrate,
        .system(.selection), .system(.success), .system(.error)
    ]

    /// Played on every swipe, so they're worth building ahead of time
    static let deck: [HapticPattern] = [
        .detent(.right), .detent(.left), .release, .bookmark, .trash, .skip, .undo, .press
    ]
}

/// Tracks whether a drag is inside one of the deck's swipe zones and reports
/// the haptic to play when that changes.
///
/// A drag enters a zone past the swipe threshold but only leaves it below a
/// fraction of the threshold, so a finger resting on the line doesn't chatter.
struct SwipeZoneTracker {
    private(set) var zone: SwipeDirection?
    var exitFraction: CGFloat = Constants.Haptics.zoneExitFraction

    mutating func update(offset: CGFloat, threshold: CGFloat) -> HapticPattern? {
        guard threshold > 0 else { return nil }
        let direction: SwipeDirection = offset >= 0 ? .right : .left
        let distance = abs(offset)

        if let current = zone {
            if direction != current, distance > threshold {
                // Flung straight across to the other zone
                zone = direction
                return .detent(direction)
            }
            if direction != current || distance < threshold * exitFraction {
                zone = nil
                return .release
            }
            return nil
        }

        guard distance > threshold else { return nil }
        zone = direction
        return .detent(direction)
    }

    mutating func reset() {
        zone = nil
    }
}
