//
//  AnalysisProgressView.swift
//  PhotoReviewApp
//
//  Compact progress banner for photo analysis
//

import SwiftUI

struct AnalysisProgressView: View {
    @ObservedObject var analysisService: PhotoAnalysisService

    private var progress: AnalysisProgress {
        analysisService.analysisProgress
    }

    var body: some View {
        if progress.isScanning {
            VStack(spacing: AppSpacing.xs) {
                HStack {
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.primary)

                    Text(progress.currentPhase.isEmpty ? "Analyzing photos..." : progress.currentPhase)
                        .font(AppTypography.labelMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    if progress.totalPhotos > 0 {
                        Text("\(progress.analyzedPhotos)/\(progress.totalPhotos)")
                            .font(AppTypography.captionBold)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Button {
                        analysisService.cancelBackgroundScan()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AppColors.primary.opacity(0.12))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AppColors.primaryGradient)
                            .frame(
                                width: geometry.size.width * progress.progress,
                                height: 4
                            )
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress.progress)
                    }
                }
                .frame(height: 4)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            .shadow(
                color: .black.opacity(0.04),
                radius: 4,
                x: 0,
                y: 2
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
