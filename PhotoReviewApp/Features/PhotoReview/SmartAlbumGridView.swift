//
//  SmartAlbumGridView.swift
//  PhotoReviewApp
//
//  Grid-based smart album browser with Apple-style design
//

import SwiftUI
import Photos

struct SmartAlbumGridView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @EnvironmentObject var photoService: PhotoLibraryService

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // People section
                if !viewModel.peopleAlbums.isEmpty {
                    peopleSection
                }

                // Smart categories grid
                smartCategoriesSection

                // Analysis progress
                if let analysisService = viewModel.analysisService,
                   analysisService.analysisProgress.isScanning {
                    AnalysisProgressView(analysisService: analysisService)
                        .padding(.horizontal, AppSpacing.md)
                }
            }
            .padding(.vertical, AppSpacing.sm)
        }
    }

    // MARK: - People Section

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                Text("People")
                    .font(AppTypography.headlineSmall)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, AppSpacing.md)

            PeoplePickerView(
                albums: viewModel.peopleAlbums,
                onSelectPerson: { person in
                    viewModel.selectPerson(person)
                },
                onDeleteAll: { person in
                    viewModel.deleteAllPhotosForPerson(person)
                }
            )
        }
    }

    // MARK: - Smart Categories Grid

    private var smartCategoriesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                Text("Smart Groups")
                    .font(AppTypography.headlineSmall)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, AppSpacing.md)

            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                ForEach(SmartCategory.allCases.filter { $0 != .people }) { category in
                    SmartAlbumCard(
                        category: category,
                        count: viewModel.smartCategoryCounts[category] ?? 0,
                        onTap: {
                            viewModel.selectSmartCategory(category)
                        }
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
}

// MARK: - Smart Album Card

struct SmartAlbumCard: View {
    let category: SmartCategory
    let count: Int
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                        .fill(category.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: category.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(category.color)
                }

                // Title & count
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(AppTypography.labelLarge)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text("\(count) photos")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous))
            .appShadow(AppSpacing.shadowSmall)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Button style with subtle scale-down on press
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.appSpring, value: configuration.isPressed)
    }
}
