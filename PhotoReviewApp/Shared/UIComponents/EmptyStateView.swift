//
//  EmptyStateView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject var viewModel: ReviewViewModel
    
    var body: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.primaryGradient)
                .symbolRenderingMode(.hierarchical)

            Text("All Caught Up!")
                .font(AppTypography.headlineLarge)
                .foregroundColor(AppColors.textPrimary)

            Text("You've reviewed all available photos")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)

            Button {
                Task { await viewModel.loadInitialPhotos() }
            } label: {
                Label("Load More", systemImage: "arrow.clockwise")
                    .font(AppTypography.button)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
