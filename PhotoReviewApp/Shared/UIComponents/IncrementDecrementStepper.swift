//
//  IncrementDecrementStepper.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 17/06/25.
//

import SwiftUI

/// A custom plus/minus stepper with haptic callbacks.
struct IncrementDecrementStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Decrement
            Button {
                guard value > range.lowerBound else { return }
                value = max(value - step, range.lowerBound)
                onDecrement()
            } label: {
                Image(systemName: "minus")
                    .font(AppTypography.captionBold)
                    .padding(AppSpacing.xs)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .disabled(value <= range.lowerBound)
            .opacity(value <= range.lowerBound ? 0.5 : 1)

            // Value display
            Text("\(value)")
                .font(AppTypography.bodyLarge.monospacedDigit())
                .frame(minWidth: 36)

            // Increment
            Button {
                guard value < range.upperBound else { return }
                value = min(value + step, range.upperBound)
                onIncrement()
            } label: {
                Image(systemName: "plus")
                    .font(AppTypography.captionBold)
                    .padding(AppSpacing.xs)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .disabled(value >= range.upperBound)
            .opacity(value >= range.upperBound ? 0.5 : 1)
        }
        .foregroundColor(AppColors.textPrimary)
    }
}

/// A stepper for storage targets (50MB - 500MB, step 50MB).
struct StorageTargetStepper: View {
    @Binding var value: Int64
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    private let stepBytes: Int64 = 50 * 1024 * 1024  // 50 MB
    private let minBytes: Int64 = 50 * 1024 * 1024   // 50 MB
    private let maxBytes: Int64 = 500 * 1024 * 1024  // 500 MB

    private var displayValue: String {
        let mb = value / (1024 * 1024)
        return "\(mb) MB"
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                guard value > minBytes else { return }
                value = max(value - stepBytes, minBytes)
                onDecrement()
            } label: {
                Image(systemName: "minus")
                    .font(AppTypography.captionBold)
                    .padding(AppSpacing.xs)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .disabled(value <= minBytes)
            .opacity(value <= minBytes ? 0.5 : 1)

            Text(displayValue)
                .font(AppTypography.bodyLarge.monospacedDigit())
                .frame(minWidth: 56)

            Button {
                guard value < maxBytes else { return }
                value = min(value + stepBytes, maxBytes)
                onIncrement()
            } label: {
                Image(systemName: "plus")
                    .font(AppTypography.captionBold)
                    .padding(AppSpacing.xs)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .disabled(value >= maxBytes)
            .opacity(value >= maxBytes ? 0.5 : 1)
        }
        .foregroundColor(AppColors.textPrimary)
    }
}
