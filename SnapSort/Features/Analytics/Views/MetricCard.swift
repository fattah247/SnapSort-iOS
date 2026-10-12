//
//  MetricCardView.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 07/02/25.
//
import SwiftUI

/// Summary tile: a colored icon tile and label above a big rounded number
struct MetricCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    let value: Text

    init(title: String, systemImage: String, tint: Color, value: Text) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.value = value
    }

    init(title: String, systemImage: String, tint: Color, value: String) {
        self.init(title: title, systemImage: systemImage, tint: tint, value: Text(value))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: systemImage)
                    .iconTile(tint, size: 28, foreground: tint == AppColors.keep ? AppColors.keepInk : .white)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            value
                .font(.title.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
        MetricCard(title: "Space Cleared", systemImage: "internaldrive", tint: AppColors.storage, value: "1.2 GB")
        MetricCard(title: "Streak", systemImage: "flame.fill", tint: AppColors.streak, value: "4 days")
    }
    .padding()
    .background(AppColors.groupedBackground)
}
