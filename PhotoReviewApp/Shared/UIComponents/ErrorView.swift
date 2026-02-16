//
//  ErrorView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 05/02/25.
//
import SwiftUI

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.deleteGradient)

            Text("Something Went Wrong")
                .font(AppTypography.headlineLarge)
                .foregroundColor(AppColors.textPrimary)

            Text(error.localizedDescription)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                retryAction()
            }
            .font(AppTypography.button)
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
        }
        .padding(AppSpacing.lg)
    }
}
