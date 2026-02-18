//
//  UndoButton.swift
//  PhotoReviewApp
//
//  Floating undo button with countdown timer
//

import SwiftUI

struct UndoButton: View {
    let action: () -> Void
    let timeRemaining: Double
    let totalTime: Double

    @State private var isPressed = false

    private var progress: Double {
        timeRemaining / totalTime
    }

    var body: some View {
        Button(action: {
            withAnimation(.appSpring) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        }) {
            ZStack {
                // Progress ring background
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    .frame(width: 56, height: 56)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)

                // Button background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)

                // Icon
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Undo Toast View
struct UndoToast: View {
    let message: String
    let timeRemaining: Double
    let totalTime: Double
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Icon
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)

            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(AppTypography.labelMedium)
                    .foregroundColor(.white)

                Text("\(Int(timeRemaining))s to undo")
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Undo button
            Button(action: onUndo) {
                Text("Undo")
                    .font(AppTypography.button)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                        .fill(Color.black.opacity(0.5))
                )
        )
        .padding(.horizontal, AppSpacing.md)
    }
}

// MARK: - Undo State Manager
@MainActor
class PhotoUndoManager: ObservableObject {
    @Published var canUndo = false
    @Published var undoMessage = ""
    @Published var timeRemaining: Double = 0

    private var undoAction: (() -> Void)?
    private var timer: Timer?
    private let undoDuration: Double = 5.0

    func setUndoAction(message: String, action: @escaping () -> Void) {
        // Cancel any existing undo
        cancelUndo()

        undoMessage = message
        undoAction = action
        timeRemaining = undoDuration
        canUndo = true

        // Start countdown
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.timeRemaining -= 0.1
                if self.timeRemaining <= 0 {
                    self.cancelUndo()
                }
            }
        }
    }

    func performUndo() {
        undoAction?()
        cancelUndo()
    }

    func cancelUndo() {
        timer?.invalidate()
        timer = nil
        canUndo = false
        undoAction = nil
        timeRemaining = 0
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()

        VStack {
            UndoToast(
                message: "Photo deleted",
                timeRemaining: 3.5,
                totalTime: 5.0,
                onUndo: {}
            )

            Spacer()

            UndoButton(
                action: {},
                timeRemaining: 3.5,
                totalTime: 5.0
            )
            .padding(.bottom, 50)
        }
    }
}
