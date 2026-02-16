//
//  AdInterstitialView.swift
//  PhotoReviewApp
//
//  Mock ad interstitial with countdown timer
//

import SwiftUI

struct AdInterstitialView: View {
    let sessionStorageSaved: Int64
    let sessionReviewCount: Int
    let onContinue: () -> Void

    @State private var timeRemaining: Int = 5
    @State private var timerActive = true

    private var canContinue: Bool { timeRemaining <= 0 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                // Session summary
                sessionSummary

                // Ad placeholder
                adPlaceholder

                // Continue button or countdown
                if canContinue {
                    Button(action: onContinue) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "play.fill")
                            Text("Continue Reviewing")
                        }
                        .font(AppTypography.button)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Continue in \(timeRemaining)s")
                        .font(AppTypography.labelMedium)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.vertical, AppSpacing.md)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .onAppear { startCountdown() }
    }

    // MARK: - Session Summary
    private var sessionSummary: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.primaryGradient)

            Text("Session Target Reached!")
                .font(AppTypography.headlineLarge)
                .foregroundColor(.white)

            HStack(spacing: AppSpacing.lg) {
                VStack(spacing: 4) {
                    Text(sessionStorageSaved.formatted(.byteCount(style: .file)))
                        .font(AppTypography.numberMedium)
                        .foregroundColor(AppColors.success)
                    Text("Saved")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                VStack(spacing: 4) {
                    Text("\(sessionReviewCount)")
                        .font(AppTypography.numberMedium)
                        .foregroundColor(AppColors.primary)
                    Text("Reviewed")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Ad Placeholder
    private var adPlaceholder: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 250)

                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "rectangle.badge.play")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))

                    Text("Advertisement")
                        .font(AppTypography.labelMedium)
                        .foregroundColor(.white.opacity(0.3))

                    // Simulated progress bar
                    if timerActive {
                        ProgressView(value: Double(5 - timeRemaining), total: 5)
                            .tint(AppColors.primary)
                            .padding(.horizontal, AppSpacing.xl)
                    }
                }
            }

            Text("Watch to continue reviewing photos")
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Timer
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    timeRemaining -= 1
                }
            } else {
                timer.invalidate()
                timerActive = false
            }
        }
    }
}

#Preview {
    AdInterstitialView(
        sessionStorageSaved: 150 * 1024 * 1024,
        sessionReviewCount: 12,
        onContinue: {}
    )
}
