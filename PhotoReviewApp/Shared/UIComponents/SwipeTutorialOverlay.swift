//
//  SwipeTutorialOverlay.swift
//  PhotoReviewApp
//
//  First-launch tutorial overlay for swipe gestures
//

import SwiftUI

struct SwipeTutorialOverlay: View {
    @Binding var isVisible: Bool
    @State private var leftArrowOffset: CGFloat = 0
    @State private var rightArrowOffset: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: AppSpacing.xl) {
                // Title
                Text("How to Review")
                    .font(AppTypography.displaySmall)
                    .foregroundColor(.white)

                // Swipe instructions
                HStack(spacing: AppSpacing.xxl) {
                    // Left swipe - Delete
                    VStack(spacing: AppSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(AppColors.deleteGradient)
                                .frame(width: 70, height: 70)

                            Image(systemName: "trash.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .offset(x: leftArrowOffset)
                            Text("Swipe Left")
                        }
                        .font(AppTypography.labelLarge)
                        .foregroundColor(.white.opacity(0.9))

                        Text("Delete")
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Divider
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 1, height: 100)

                    // Right swipe - Bookmark
                    VStack(spacing: AppSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(AppColors.bookmarkGradient)
                                .frame(width: 70, height: 70)

                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }

                        HStack(spacing: 4) {
                            Text("Swipe Right")
                            Image(systemName: "arrow.right")
                                .offset(x: rightArrowOffset)
                        }
                        .font(AppTypography.labelLarge)
                        .foregroundColor(.white.opacity(0.9))

                        Text("Bookmark")
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Tap to dismiss
                Text("Tap anywhere to start")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, AppSpacing.md)
            }
            .padding(AppSpacing.xl)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 1
            }
            startArrowAnimation()
        }
    }

    private func startArrowAnimation() {
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            leftArrowOffset = -8
            rightArrowOffset = 8
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isVisible = false
            UserDefaults.standard.set(true, forKey: "hasSeenSwipeTutorial")
        }
    }
}

// MARK: - Tutorial State Manager
class SwipeTutorialManager {
    static var shouldShowTutorial: Bool {
        !UserDefaults.standard.bool(forKey: "hasSeenSwipeTutorial")
    }

    static func markAsSeen() {
        UserDefaults.standard.set(true, forKey: "hasSeenSwipeTutorial")
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: "hasSeenSwipeTutorial")
    }
}

#Preview {
    SwipeTutorialOverlay(isVisible: .constant(true))
}
