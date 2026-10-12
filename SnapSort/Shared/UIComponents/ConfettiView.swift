//
//  ConfettiView.swift
//  SnapSort
//
//  A short celebratory burst. Skipped entirely when Reduce Motion is on.
//

import SwiftUI

struct ConfettiView: View {
    var pieceCount = 70
    var duration: TimeInterval = 2.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()
    @State private var pieces: [Piece] = []

    private struct Piece {
        let x: Double          // 0…1 across the width
        let delay: Double
        let fallSpeed: Double  // points per second
        let sway: Double
        let spin: Double
        let size: CGSize
        let color: Color
        let isCircle: Bool
    }

    private static let palette: [Color] = [
        AppColors.brand, AppColors.keep, AppColors.delete, AppColors.storage, AppColors.streak
    ]

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(startDate)
                    let fade = max(0, min(1, (duration - elapsed) / 0.6))
                    for piece in pieces {
                        let t = elapsed - piece.delay
                        guard t > 0 else { continue }
                        let y = -20 + t * piece.fallSpeed
                        guard y < size.height + 20 else { continue }
                        let x = piece.x * size.width + sin(t * 3 + piece.sway) * 18
                        var pieceContext = context
                        pieceContext.opacity = fade
                        pieceContext.translateBy(x: x, y: y)
                        pieceContext.rotate(by: .radians(t * piece.spin))
                        let rect = CGRect(
                            x: -piece.size.width / 2,
                            y: -piece.size.height / 2,
                            width: piece.size.width,
                            height: piece.size.height
                        )
                        let path = piece.isCircle
                            ? Path(ellipseIn: rect)
                            : Path(roundedRect: rect, cornerRadius: 2)
                        pieceContext.fill(path, with: .color(piece.color))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                startDate = Date()
                pieces = (0..<pieceCount).map { _ in
                    let isCircle = Bool.random()
                    let side = Double.random(in: 7...11)
                    return Piece(
                        x: .random(in: 0...1),
                        delay: .random(in: 0...0.5),
                        fallSpeed: .random(in: 260...460),
                        sway: .random(in: 0...(2 * .pi)),
                        spin: .random(in: -6...6),
                        size: isCircle ? CGSize(width: side, height: side) : CGSize(width: side * 0.6, height: side * 1.4),
                        color: Self.palette.randomElement() ?? AppColors.brand,
                        isCircle: isCircle
                    )
                }
            }
        }
    }
}
