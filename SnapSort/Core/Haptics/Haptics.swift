//
//  Haptics.swift
//  SnapSort
//
//  Plays `HapticPattern`s on the Taptic Engine.
//
//  Feedback only feels connected to a touch when it lands on the same frame,
//  so the engine is woken before it's needed (when the app becomes active and
//  when a drag starts) and every pattern's player is built once and reused.
//

import CoreHaptics
import OSLog
import SwiftUI
import UIKit

@MainActor
protocol HapticsProtocol: AnyObject {
    /// Gets the hardware ready so the next pattern plays without delay
    func prepare()
    func play(_ pattern: HapticPattern)
}

/// Where patterns end up. The real one drives the hardware; tests record calls.
@MainActor
protocol HapticOutput: AnyObject {
    func prepare(_ patterns: [HapticPattern])
    func play(_ pattern: HapticPattern)
}

@MainActor
final class Haptics: ObservableObject, HapticsProtocol {
    /// People can turn haptics off in Settings
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Constants.UserDefaultsKeys.hapticsEnabled) }
    }

    private let output: HapticOutput
    private let defaults: UserDefaults
    private let clock: () -> TimeInterval
    private var lastPlayed: [HapticPattern: TimeInterval] = [:]

    init(
        output: HapticOutput? = nil,
        defaults: UserDefaults = .standard,
        clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.output = output ?? DeviceHapticOutput()
        self.defaults = defaults
        self.clock = clock
        isEnabled = defaults.object(forKey: Constants.UserDefaultsKeys.hapticsEnabled) as? Bool ?? true
    }

    func prepare() {
        guard isEnabled else { return }
        output.prepare(HapticPattern.deck)
    }

    func play(_ pattern: HapticPattern) {
        guard isEnabled else { return }
        let pattern = pattern.normalized

        // Rapid repeats of the same pattern blur into a buzz
        let now = clock()
        if let last = lastPlayed[pattern], now - last < Constants.Haptics.repeatGuard { return }
        lastPlayed[pattern] = now

        output.play(pattern)
    }

    #if DEBUG
    /// Plays a one-off tap for tuning in the Haptics Lab
    func playTap(intensity: Float, sharpness: Float) {
        (output as? DeviceHapticOutput)?.playTap(intensity: intensity, sharpness: sharpness)
    }
    #endif
}

// MARK: - Device Output

@MainActor
final class DeviceHapticOutput: HapticOutput {
    private let supportsCustomHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var isRunning = false
    private var players: [HapticPattern: CHHapticPatternPlayer] = [:]
    private var idleShutdown: Task<Void, Never>?

    /// The engine is stopped after this long without feedback, to save power.
    /// Core Haptics' own auto-shutdown would delay the first tap after waking,
    /// so wake-ups happen on our schedule instead (see `prepare`).
    private let idleTimeout: Duration = .seconds(20)

    private var impactGenerators: [HapticFallback.ImpactWeight: UIImpactFeedbackGenerator] = [:]
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    func prepare(_ patterns: [HapticPattern]) {
        guard supportsCustomHaptics else {
            selectionGenerator.prepare()
            return
        }
        startEngine()
        for pattern in patterns where players[pattern] == nil {
            players[pattern] = try? makePlayer(for: pattern)
        }
        scheduleIdleShutdown()
    }

    func play(_ pattern: HapticPattern) {
        guard supportsCustomHaptics, !pattern.isSystem else {
            playFallback(pattern.fallback)
            return
        }
        startEngine()
        do {
            let player = try players[pattern] ?? makePlayer(for: pattern)
            players[pattern] = player
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            AppLogger.general.error("Haptic pattern failed: \(error.localizedDescription, privacy: .public)")
            playFallback(pattern.fallback)
        }
        scheduleIdleShutdown()
    }

    #if DEBUG
    func playTap(intensity: Float, sharpness: Float) {
        guard supportsCustomHaptics else { return }
        startEngine()
        let pattern = try? CHHapticPattern(
            events: [Self.coreEvent(.tap(at: 0, intensity: intensity, sharpness: sharpness))],
            parameterCurves: []
        )
        if let pattern, let player = try? engine?.makePlayer(with: pattern) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
        scheduleIdleShutdown()
    }
    #endif

    // MARK: Engine

    private func startEngine() {
        if engine == nil { engine = makeEngine() }
        guard !isRunning, let engine else { return }
        do {
            try engine.start()
            isRunning = true
        } catch {
            AppLogger.general.error("Haptic engine didn't start: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func makeEngine() -> CHHapticEngine? {
        do {
            let engine = try CHHapticEngine()
            // Haptics only, so it never touches the audio session or interrupts music
            engine.playsHapticsOnly = true
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.isRunning = false }
            }
            engine.resetHandler = { [weak self] in
                // The haptic server restarted; players from before are no longer valid
                Task { @MainActor in
                    guard let self else { return }
                    self.isRunning = false
                    self.players.removeAll()
                    self.startEngine()
                }
            }
            return engine
        } catch {
            AppLogger.general.error("Haptic engine unavailable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func scheduleIdleShutdown() {
        idleShutdown?.cancel()
        idleShutdown = Task { [weak self, idleTimeout] in
            try? await Task.sleep(for: idleTimeout)
            guard !Task.isCancelled, let self, self.isRunning else { return }
            self.engine?.stop(completionHandler: nil)
            self.isRunning = false
        }
    }

    // MARK: Patterns

    private func makePlayer(for pattern: HapticPattern) throws -> CHHapticPatternPlayer {
        guard let engine else { throw CocoaError(.featureUnsupported) }
        var events: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []

        for event in pattern.events {
            events.append(Self.coreEvent(event))
            // Continuous events fade by scaling their peak with an intensity curve
            if case .continuous(let duration, let end) = event.kind, event.peakIntensity > 0 {
                let peak = event.peakIntensity
                curves.append(CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        .init(relativeTime: 0, value: event.intensity / peak),
                        .init(relativeTime: duration, value: end / peak)
                    ],
                    relativeTime: event.time
                ))
            }
        }
        return try engine.makePlayer(with: CHHapticPattern(events: events, parameterCurves: curves))
    }

    private static func coreEvent(_ event: HapticEvent) -> CHHapticEvent {
        let parameters = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: event.peakIntensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness)
        ]
        switch event.kind {
        case .tap:
            return CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: event.time)
        case .continuous(let duration, _):
            return CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: parameters,
                relativeTime: event.time,
                duration: duration
            )
        }
    }

    // MARK: Fallback

    private func playFallback(_ fallback: HapticFallback) {
        switch fallback {
        case .impact(let weight, let intensity):
            let generator = impactGenerators[weight] ?? UIImpactFeedbackGenerator(style: weight.style)
            impactGenerators[weight] = generator
            generator.impactOccurred(intensity: CGFloat(intensity))
            generator.prepare()
        case .selection:
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
    }
}

private extension HapticFallback.ImpactWeight {
    var style: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: .light
        case .medium: .medium
        case .soft: .soft
        case .rigid: .rigid
        }
    }
}

// MARK: - SwiftUI

extension EnvironmentValues {
    /// Nil in previews and anywhere the app hasn't injected it, which plays nothing
    @Entry var haptics: Haptics?
}
