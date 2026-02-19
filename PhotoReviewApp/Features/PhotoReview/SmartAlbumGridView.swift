//
//  SmartAlbumGridView.swift
//  PhotoReviewApp
//
//  Grid-based smart album browser with Apple-style design
//

import SwiftUI

struct SmartAlbumGridView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @EnvironmentObject var photoService: PhotoLibraryService
    @State private var dismissedScanningOverlay = false

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    private var shouldShowScanningOverlay: Bool {
        guard !dismissedScanningOverlay,
              let analysisService = viewModel.analysisService,
              analysisService.analysisProgress.isScanning else { return false }
        let hasResults = viewModel.smartCategoryCounts.values.contains { $0 > 0 }
        return !hasResults
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Analysis progress banner — only when overlay is NOT shown
                    if !shouldShowScanningOverlay,
                       let analysisService = viewModel.analysisService,
                       analysisService.analysisProgress.isScanning {
                        AnalysisProgressView(analysisService: analysisService)
                            .padding(.horizontal, AppSpacing.md)
                    }

                    // People section
                    if !viewModel.peopleAlbums.isEmpty {
                        peopleSection
                    }

                    // Smart categories grid
                    smartCategoriesSection
                }
                .padding(.vertical, AppSpacing.sm)
            }

            if shouldShowScanningOverlay {
                ScanningOverlayView(
                    progress: viewModel.analysisService?.analysisProgress ?? AnalysisProgress(),
                    onBrowseAnyway: {
                        withAnimation(.appSpring) {
                            dismissedScanningOverlay = true
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .onChange(of: viewModel.smartCategoryCounts) { _, counts in
            if counts.values.contains(where: { $0 > 0 }) {
                withAnimation(.appSpring) {
                    dismissedScanningOverlay = true
                }
            }
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
                let isScanning = viewModel.analysisService?.analysisProgress.isScanning == true
                ForEach(SmartCategory.allCases.filter { $0 != .people }) { category in
                    SmartAlbumCard(
                        category: category,
                        count: viewModel.smartCategoryCounts[category] ?? 0,
                        isScanning: isScanning,
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
    var isScanning: Bool = false
    let onTap: () -> Void

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

                    if count == 0 && isScanning {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                            Text("Scanning...")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    } else {
                        Text("\(count) photos")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
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

// MARK: - Scanning Overlay

struct ScanningOverlayView: View {
    let progress: AnalysisProgress
    let onBrowseAnyway: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            // Pulsing sparkle icon
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)

                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(AppColors.primaryGradient)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
            }

            VStack(spacing: AppSpacing.sm) {
                Text("Analyzing Your Library")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("We're scanning your photos to find duplicates, blurry shots, and more. This only happens once.")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            // Progress bar with count
            VStack(spacing: AppSpacing.xs) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AppColors.primary.opacity(0.12))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AppColors.primaryGradient)
                            .frame(
                                width: geometry.size.width * progress.progress,
                                height: 8
                            )
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress.progress)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, AppSpacing.xl)

                if progress.totalPhotos > 0 {
                    Text("\(progress.analyzedPhotos) of \(progress.totalPhotos) photos analyzed")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            Button {
                onBrowseAnyway()
            } label: {
                Text("Browse anyway")
                    .font(AppTypography.labelMedium)
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        Capsule()
                            .fill(AppColors.primary.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.groupedBackground)
    }
}
