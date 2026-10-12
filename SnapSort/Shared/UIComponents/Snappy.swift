//
//  Snappy.swift
//  SnapSort
//
//  The SnapSort mascot: a small camera whose lens is its face.
//  Purely decorative — always hidden from VoiceOver.
//

import SwiftUI

struct Snappy: View {
    enum Mood {
        case happy, cheer, sleepy, curious
    }

    var mood: Mood = .happy
    var size: CGFloat = 96
    /// Gentle bob and blink. Ignored when Reduce Motion is on.
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bobUp = false
    @State private var isBlinking = false

    // Fixed colors so the face reads the same in light and dark mode
    private let lens = Color(red: 1.0, green: 0.97, blue: 0.91)
    private let ink = Color(red: 0.17, green: 0.15, blue: 0.13)

    private var isAnimating: Bool { animated && !reduceMotion }

    var body: some View {
        let s = size
        ZStack {
            // Shutter button
            Capsule()
                .fill(AppColors.keep)
                .frame(width: s * 0.26, height: s * 0.14)
                .offset(x: -s * 0.2, y: -s * 0.39)

            // Body
            RoundedRectangle(cornerRadius: s * 0.28, style: .continuous)
                .fill(AppColors.brand)
                .frame(width: s, height: s * 0.8)
                .offset(y: s * 0.04)
                .overlay(alignment: .topTrailing) {
                    // Flash window
                    RoundedRectangle(cornerRadius: s * 0.04, style: .continuous)
                        .fill(lens.opacity(0.85))
                        .frame(width: s * 0.16, height: s * 0.1)
                        .offset(x: -s * 0.1, y: s * 0.17)
                }

            // Lens ring + face
            Circle()
                .fill(Color.black.opacity(0.12))
                .frame(width: s * 0.66, height: s * 0.66)
                .offset(y: s * 0.08)
            Circle()
                .fill(lens)
                .frame(width: s * 0.58, height: s * 0.58)
                .offset(y: s * 0.08)

            face
                .frame(width: s * 0.58, height: s * 0.58)
                .offset(y: s * 0.08)

            if mood == .sleepy {
                sleepyZs
            }
        }
        .frame(width: s, height: s)
        .offset(y: isAnimating ? (bobUp ? -s * 0.025 : s * 0.025) : 0)
        .accessibilityHidden(true)
        .onAppear {
            guard isAnimating else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                bobUp = true
            }
        }
        .task {
            guard isAnimating, mood == .happy || mood == .curious else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.5...4.5)))
                withAnimation(.easeInOut(duration: 0.08)) { isBlinking = true }
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeInOut(duration: 0.1)) { isBlinking = false }
            }
        }
    }

    // MARK: - Face

    @ViewBuilder
    private var face: some View {
        let s = size
        let eyeSpacing = s * 0.12
        ZStack {
            // Cheeks
            HStack(spacing: s * 0.24) {
                Ellipse().fill(AppColors.delete.opacity(0.28))
                Ellipse().fill(AppColors.delete.opacity(0.28))
            }
            .frame(width: s * 0.44, height: s * 0.06)
            .offset(y: s * 0.07)

            switch mood {
            case .happy:
                HStack(spacing: eyeSpacing) { roundEye; roundEye }
                    .offset(y: -s * 0.04)
                SmileShape()
                    .stroke(ink, style: StrokeStyle(lineWidth: s * 0.028, lineCap: .round))
                    .frame(width: s * 0.12, height: s * 0.05)
                    .offset(y: s * 0.08)

            case .cheer:
                HStack(spacing: eyeSpacing) { arcEye(up: true); arcEye(up: true) }
                    .offset(y: -s * 0.05)
                OpenMouthShape()
                    .fill(ink)
                    .overlay(alignment: .bottom) {
                        Ellipse()
                            .fill(AppColors.delete)
                            .frame(width: s * 0.07, height: s * 0.035)
                            .offset(y: -s * 0.006)
                    }
                    .clipShape(OpenMouthShape())
                    .frame(width: s * 0.15, height: s * 0.08)
                    .offset(y: s * 0.08)

            case .sleepy:
                HStack(spacing: eyeSpacing) { arcEye(up: false); arcEye(up: false) }
                    .offset(y: -s * 0.02)
                Ellipse()
                    .stroke(ink, lineWidth: s * 0.022)
                    .frame(width: s * 0.05, height: s * 0.04)
                    .offset(y: s * 0.09)

            case .curious:
                HStack(spacing: eyeSpacing) { roundEye; roundEye }
                    .scaleEffect(1.12)
                    .offset(y: -s * 0.04)
                Circle()
                    .stroke(ink, lineWidth: s * 0.024)
                    .frame(width: s * 0.06, height: s * 0.06)
                    .offset(y: s * 0.09)
            }
        }
    }

    private var roundEye: some View {
        let s = size
        return Ellipse()
            .fill(ink)
            .frame(width: s * 0.08, height: s * 0.11)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(.white)
                    .frame(width: s * 0.03, height: s * 0.03)
                    .offset(x: -s * 0.008, y: s * 0.015)
            }
            .scaleEffect(x: 1, y: isBlinking ? 0.1 : 1)
    }

    private func arcEye(up: Bool) -> some View {
        let s = size
        return EyeArcShape(curvesUp: up)
            .stroke(ink, style: StrokeStyle(lineWidth: s * 0.028, lineCap: .round))
            .frame(width: s * 0.09, height: s * 0.045)
    }

    private var sleepyZs: some View {
        let s = size
        return ZStack {
            Text("z").font(.system(size: s * 0.22, weight: .heavy, design: .rounded))
                .offset(x: s * 0.1, y: -s * 0.12)
            Text("z").font(.system(size: s * 0.15, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.secondary)
        .offset(x: s * 0.56, y: -s * 0.42)
    }
}

// MARK: - Face Shapes

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 2)
        )
        return path
    }
}

private struct OpenMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 2)
        )
        path.closeSubpath()
        return path
    }
}

/// "^" when curving up (happy squint), "‿" when curving down (asleep)
private struct EyeArcShape: Shape {
    let curvesUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseline = curvesUp ? rect.maxY : rect.minY
        let control = curvesUp ? rect.minY - rect.height : rect.maxY + rect.height
        path.move(to: CGPoint(x: rect.minX, y: baseline))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: baseline),
            control: CGPoint(x: rect.midX, y: control)
        )
        return path
    }
}

#Preview {
    HStack(spacing: 24) {
        Snappy(mood: .happy, size: 80)
        Snappy(mood: .cheer, size: 80)
        Snappy(mood: .sleepy, size: 80)
        Snappy(mood: .curious, size: 80)
    }
    .padding(40)
    .background(AppColors.groupedBackground)
}
