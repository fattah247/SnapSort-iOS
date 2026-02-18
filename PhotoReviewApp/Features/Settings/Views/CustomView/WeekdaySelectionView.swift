//
//  WeekdaySelectionView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 16/06/25.
//

import SwiftUI

struct WeekdaySelectionView: View {
    @Binding var selection: [Weekday]
    
    let columns = [GridItem(.adaptive(minimum: 44, maximum: 60), spacing: AppSpacing.sm)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
            ForEach(Weekday.allCases) { day in
                Text(day.shortName)
                    .font(AppTypography.labelLarge)
                    .monospacedDigit()
                    .frame(width: 44, height: 44)
                    .background(
                        selection.contains(day)
                        ? AnyView(AppColors.primaryGradient)
                        : AnyView(Color(.tertiarySystemFill))
                    )
                    .foregroundColor(selection.contains(day) ? .white : AppColors.textPrimary)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                    )
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(.appSpring) {
                            if let idx = selection.firstIndex(of: day) {
                                selection.remove(at: idx)
                            } else {
                                selection.append(day)
                            }
                        }
                    }
            }
        }
        .padding(.vertical, AppSpacing.xxs)
    }
}
