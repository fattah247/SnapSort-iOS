//
//  PhotoReviewView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 28/01/25.
//
import SwiftUI
import Photos

struct ReviewView: View {
    @StateObject private var viewModel: ReviewViewModel
    @StateObject private var undoManager = PhotoUndoManager()
    private let haptic: any HapticServiceProtocol

    @EnvironmentObject private var settings: SettingsViewModel
    @EnvironmentObject private var bookmarkManager: CoreDataBookmarkManager
    @EnvironmentObject private var trashManager: CoreDataTrashManager
    @EnvironmentObject private var analyticsService: CoreDataAnalyticsService

    @State private var showTutorial = SwipeTutorialManager.shouldShowTutorial
    @State private var showAdInterstitial = false
    @State private var selectedAsset: PHAsset?

    init(
        photoService: any PhotoLibraryServiceProtocol,
        haptic: any HapticServiceProtocol,
        analytics: any AnalyticsServiceProtocol,
        bookmarkManager: CoreDataBookmarkManager,
        trashManager: CoreDataTrashManager,
        settings: SettingsViewModel,
        smartCategoryService: SmartCategoryService? = nil,
        analysisService: PhotoAnalysisService? = nil,
        peopleService: PeopleService? = nil
    ) {
        self.haptic = haptic
        _viewModel = StateObject(wrappedValue: ReviewViewModel(
            photoService: photoService,
            haptic: haptic,
            analytics: analytics,
            bookmarkManager: bookmarkManager,
            trashManager: trashManager,
            settings: settings,
            smartCategoryService: smartCategoryService,
            analysisService: analysisService,
            peopleService: peopleService
        ))
    }

    var body: some View {
        ZStack {
            AppColors.groupedBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with streak
                headerView

                // Storage progress bar
                storageProgressBar

                // Mode picker: Library / Smart
                modePicker

                // Content based on mode
                if viewModel.reviewMode == .library || viewModel.isInSmartSwipeMode {
                    // Library mode or Smart swipe mode
                    if viewModel.reviewMode == .library {
                        categoryPicker
                    } else if viewModel.isInSmartSwipeMode {
                        smartSwipeHeader
                    }

                    contentSwitch
                        .frame(maxHeight: .infinity)
                        .transition(.opacity.combined(with: .scale(0.95)))
                } else {
                    // Smart browse mode — show grid
                    SmartAlbumGridView(viewModel: viewModel)
                        .frame(maxHeight: .infinity)
                        .transition(.opacity.combined(with: .scale(0.95)))
                }
            }

            // Undo toast
            if undoManager.canUndo {
                VStack {
                    Spacer()
                    UndoToast(
                        message: undoManager.undoMessage,
                        timeRemaining: undoManager.timeRemaining,
                        totalTime: 5.0,
                        onUndo: {
                            undoManager.performUndo()
                        }
                    )
                    .padding(.bottom, AppSpacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: undoManager.canUndo)
            }

            // Tutorial overlay
            if showTutorial {
                SwipeTutorialOverlay(isVisible: $showTutorial)
                    .transition(.opacity)
            }

            // Ad interstitial overlay
            if showAdInterstitial {
                AdInterstitialView(
                    sessionStorageSaved: viewModel.sessionStorageSaved,
                    sessionReviewCount: viewModel.sessionReviewCount,
                    onContinue: {
                        withAnimation(.appSpring) {
                            showAdInterstitial = false
                        }
                        viewModel.startNewSession()
                    }
                )
                .transition(.opacity)
            }
        }
        .task {
            await viewModel.loadInitialPhotos()
        }
        .alert("Confirm Deletion", isPresented: $viewModel.showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                viewModel.pendingDeletePhoto = nil
            }
            Button("Delete", role: .destructive) {
                viewModel.confirmDeletion(of: viewModel.pendingDeletePhoto)
            }
        }
        .onChange(of: viewModel.sessionTargetReached) { _, reached in
            if reached {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showAdInterstitial = true
                }
            }
        }
        .onChange(of: viewModel.reviewMode) { _, newMode in
            if newMode == .smart {
                viewModel.loadSmartData()
            }
        }
        .onReceive(
            // Refresh smart counts periodically while scan is running
            Timer.publish(every: 10, on: .main, in: .common).autoconnect()
        ) { _ in
            if viewModel.reviewMode == .smart,
               !viewModel.isInSmartSwipeMode,
               let analysisService = viewModel.analysisService,
               analysisService.analysisProgress.isScanning {
                viewModel.refreshSmartCounts()
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text("Review")
                    .font(AppTypography.displaySmall)
                    .foregroundColor(AppColors.textPrimary)

                Text("Swipe to organize your photos")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Streak badge
            streakBadge
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    private var streakBadge: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundColor(AppColors.streak)

            Text("\(analyticsService.currentStreak)")
                .font(AppTypography.numberSmall)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Capsule()
                .fill(AppColors.streak.opacity(0.15))
        )
    }

    // MARK: - Storage Progress Bar
    private var storageProgressBar: some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "externaldrive.badge.plus")
                        .font(.system(size: 11))
                    Text(viewModel.sessionStorageSaved.formatted(.byteCount(style: .file)))
                        .font(AppTypography.caption)
                }
                .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("Target: \(viewModel.storageTarget.formatted(.byteCount(style: .file)))")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppColors.primary.opacity(0.12))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppColors.primaryGradient)
                        .frame(width: geometry.size.width * viewModel.storageProgress, height: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.storageProgress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
    }

    // MARK: - Mode Picker (Library / Smart)
    private var modePicker: some View {
        Picker("Mode", selection: $viewModel.reviewMode) {
            ForEach(ReviewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
    }

    // MARK: - Smart Swipe Header (back button + category name)
    private var smartSwipeHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                withAnimation(.appSpring) {
                    viewModel.exitSmartSwipeMode()
                }
            } label: {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Smart Groups")
                        .font(AppTypography.labelMedium)
                }
                .foregroundColor(AppColors.primary)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: viewModel.selectedCategory.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(viewModel.selectedCategory.displayName)
                    .font(AppTypography.labelMedium)
            }
            .foregroundColor(viewModel.selectedCategory.color)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(
                Capsule()
                    .fill(viewModel.selectedCategory.color.opacity(0.12))
            )
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Category Picker
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(PhotoCategory.allCases) { category in
                    CategoryChip(
                        category: category,
                        isSelected: viewModel.selectedCategory == .library(category),
                        onTap: {
                            viewModel.selectLibraryCategory(category)
                        }
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
        }
    }

    // MARK: - Content Switch
    @ViewBuilder
    private var contentSwitch: some View {
        switch viewModel.state {
        case .idle:
            loadingPlaceholder
        case .loading:
            loadingView
        case .loaded(let photos):
            if photos.isEmpty {
                emptyStateView
            } else {
                cardStackView(photos: photos)
            }
        case .error(let error):
            errorView(error: error)
        }
    }

    // MARK: - Card Stack View
    private func cardStackView(photos: [Photo]) -> some View {
        GeometryReader { geometry in
            let visiblePhotos = photos.suffix(3)
            let totalCount = photos.count
            ZStack {
                ForEach(Array(visiblePhotos.enumerated()), id: \.element.id) { offset, photo in
                    let indexFromTop = visiblePhotos.count - 1 - offset
                    PhotoCardView(
                        photo: photo,
                        viewModel: viewModel,
                        onTap: {
                            selectedAsset = viewModel.asset(for: photo.id)
                        },
                        onSkip: {
                            viewModel.skipPhoto(photo)
                        }
                    )
                    .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.95)
                    .zIndex(Double(totalCount - indexFromTop))
                }

                // Loading-more indicator at the bottom
                if viewModel.isLoadingMore {
                    VStack {
                        Spacer()
                        HStack(spacing: AppSpacing.xs) {
                            ProgressView()
                                .tint(AppColors.primary)
                            Text("Loading more...")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.vertical, AppSpacing.xs)
                        .padding(.horizontal, AppSpacing.sm)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.25), value: viewModel.isLoadingMore)
                    .zIndex(Double(photos.count + 1))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .sheet(item: $selectedAsset) { asset in
            PhotoDetailView(asset: asset)
        }
    }

    // MARK: - Loading Views
    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                .scaleEffect(1.5)

            Text("Curating Your Memories")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .transition(.opacity)
            Spacer()
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            RoundedRectangle(cornerRadius: AppSpacing.radiusXLarge)
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 300, height: 450)
                .shimmering()
            Spacer()
        }
    }

    // MARK: - Error View
    private func errorView(error: Error) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppColors.warning.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(AppColors.warning)
            }

            Text("Couldn't Load Photos")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            Text(error.localizedDescription)
                .font(AppTypography.bodySmall)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.xl)

            Button(action: {
                Task { await viewModel.loadInitialPhotos() }
            }) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(AppTypography.button)
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.primaryGradient)
                .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(AppSpacing.xl)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AppColors.success)
            }

            Text("All Caught Up!")
                .font(AppTypography.headlineLarge)
                .foregroundColor(AppColors.textPrimary)

            Text("You've reviewed all your photos.\nCome back later for more!")
                .font(AppTypography.bodyMedium)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)

            Button(action: {
                Task { await viewModel.loadInitialPhotos() }
            }) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.clockwise")
                    Text("Load More")
                }
                .font(AppTypography.button)
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.primaryGradient)
                .clipShape(Capsule())
            }
            .padding(.top, AppSpacing.sm)
            Spacer()
        }
        .padding(AppSpacing.xl)
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: PhotoCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))

                Text(category.rawValue)
                    .font(AppTypography.labelSmall)
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : category.color)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? category.color : category.color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .animation(.appSpring, value: isSelected)
    }
}

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerEffect())
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .mask(content)
                .offset(x: phase * 200)
                .animation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: phase
                )
                .onAppear { phase = 1 }
            )
    }
}
