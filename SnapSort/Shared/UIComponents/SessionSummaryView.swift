//
//  SessionSummaryView.swift
//  SnapSort
//
//  Shown when a review session reaches its storage goal.
//

import SwiftUI

struct SessionSummaryView: View {
    let onContinue: () -> Void
    let onReviewTrash: () -> Void

    // Captured once so the numbers don't change while the cover animates away
    @State private var storageSaved: Int64
    @State private var reviewCount: Int
    @State private var trashCount: Int

    @Environment(\.haptics) private var haptics

    init(
        storageSaved: Int64,
        reviewCount: Int,
        trashCount: Int,
        onContinue: @escaping () -> Void,
        onReviewTrash: @escaping () -> Void
    ) {
        _storageSaved = State(initialValue: storageSaved)
        _reviewCount = State(initialValue: reviewCount)
        _trashCount = State(initialValue: trashCount)
        self.onContinue = onContinue
        self.onReviewTrash = onReviewTrash
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: AppSpacing.md)

            summary

            Spacer(minLength: AppSpacing.md)

            VStack(spacing: AppSpacing.sm) {
                Button(action: onContinue) {
                    ChunkyLabel(title: "Keep Sorting")
                }
                .buttonStyle(.chunky)

                if trashCount > 0 {
                    Button(action: onReviewTrash) {
                        ChunkyLabel(title: "Review Trash (\(trashCount))", systemImage: "trash")
                    }
                    .buttonStyle(.chunky(AppColors.cardBackground, foreground: .primary))
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.groupedBackground)
        .overlay(alignment: .top) {
            ConfettiView()
        }
        // Starts with the confetti burst
        .onAppear { haptics?.play(.celebrate) }
        .interactiveDismissDisabled()
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: AppSpacing.sm) {
            Snappy(mood: .cheer, size: 120)

            Text("Goal reached!")
                .font(.largeTitle.bold())

            Text("You sorted ^[\(reviewCount) photo](inflect: true) and marked \(storageSaved.storageText) for deletion. Nice tidying!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    SessionSummaryView(
        storageSaved: 150 * 1024 * 1024,
        reviewCount: 12,
        trashCount: 8,
        onContinue: {},
        onReviewTrash: {}
    )
}
