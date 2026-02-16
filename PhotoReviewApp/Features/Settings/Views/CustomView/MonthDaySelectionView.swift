//
//  MonthDaySelectionView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 16/06/25.
//

import SwiftUI

struct MonthDaySelectionView: View {
    @Binding var selection: Int
    @Environment(\.horizontalSizeClass) var hSize
    
    private let columns = Array(repeating: GridItem(.flexible(minimum: 30, maximum: 44), spacing: AppSpacing.xs), count: 7)
    
    var body: some View {
        Group {
            if hSize == .compact {
                HStack {
                    Text("Day")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    IncrementDecrementStepper(
                        value: $selection,
                        range: 1...31,
                        step: 1,
                        onIncrement: {},
                        onDecrement: {}
                    )
                }
            } else {
                LazyVGrid(columns: columns, spacing: AppSpacing.xs) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)")
                            .font(AppTypography.labelLarge)
                            .monospacedDigit()
                            .frame(minWidth: 36, minHeight: 36)
                            .background(
                                selection == day
                                ? AnyView(AppColors.primaryGradient)
                                : AnyView(Color(.tertiarySystemFill))
                            )
                            .foregroundColor(selection == day ? .white : AppColors.textPrimary)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                            )
                            .contentShape(Circle())
                            .onTapGesture {
                                withAnimation(.appSpring) {
                                    selection = day
                                }
                            }
                    }
                }
                .padding(.vertical, AppSpacing.xxs)
            }
        }
    }
}

