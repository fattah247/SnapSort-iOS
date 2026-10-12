//
//  AnalysisProgressView.swift
//  SnapSort
//
//  List section showing photo analysis progress
//

import SwiftUI

struct AnalysisProgressView: View {
    @ObservedObject var analysisService: PhotoAnalysisService

    private var progress: AnalysisProgress {
        analysisService.analysisProgress
    }

    var body: some View {
        if progress.isScanning {
            Section {
                HStack(alignment: .center, spacing: AppSpacing.sm) {
                    Snappy(mood: .curious, size: 56)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(progress.currentPhase.isEmpty ? "Looking through your photos…" : progress.currentPhase)
                            .font(.subheadline.weight(.semibold))
                        ProgressView(value: progress.totalPhotos > 0 ? progress.progress : nil)
                            .progressViewStyle(.chunky)
                        if progress.totalPhotos > 0 {
                            Text("\(progress.analyzedPhotos.formatted()) of \(progress.totalPhotos.formatted())")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, AppSpacing.xxs)
                .accessibilityElement(children: .combine)

                Button("Pause for Now") {
                    analysisService.cancelBackgroundScan()
                }
            } footer: {
                Text("Groups fill in as SnapSort goes. It only looks at each photo once.")
            }
            .listRowBackground(AppColors.cardBackground)
        }
    }
}
