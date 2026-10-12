//
//  ReviewView.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 28/01/25.
//
import SwiftUI
import Photos

struct ReviewView: View {
    @StateObject private var viewModel: ReviewViewModel

    @EnvironmentObject private var appState: AppStateManager
    @EnvironmentObject private var trashManager: CoreDataTrashManager
    @EnvironmentObject private var analytics: CoreDataAnalyticsService
    @Environment(\.scenePhase) private var scenePhase

    /// Smart groups and people push a deck onto this path
    @State private var smartPath: [CategorySelection] = []
    @State private var showTips = false

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
        NavigationStack(path: $smartPath) {
            Group {
                switch viewModel.reviewMode {
                case .library:
                    ReviewDeckView(viewModel: viewModel) {
                        categoryMenu
                    }
                case .smart:
                    SmartGroupsView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.groupedBackground)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    modePicker
                }
                if viewModel.reviewMode == .library {
                    ToolbarItem(placement: .topBarTrailing) {
                        undoButton
                    }
                }
            }
            .navigationDestination(for: CategorySelection.self) { selection in
                if selection == .smart(.duplicates) {
                    SimilarShotsView(viewModel: viewModel)
                } else {
                    ReviewDeckView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppColors.groupedBackground)
                        .navigationTitle(selection.displayName)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                undoButton
                            }
                        }
                }
            }
        }
        .onAppear {
            viewModel.loadIfNeeded()
            if SwipeTutorialManager.shouldShowTutorial {
                showTips = true
            }
        }
        .onChange(of: viewModel.reviewMode) { _, mode in
            switch mode {
            case .library: viewModel.showLibrary()
            case .smart: viewModel.loadSmartData()
            }
        }
        .onChange(of: smartPath) { oldPath, newPath in
            if newPath.count > oldPath.count, let selection = newPath.last {
                // Similar shots have their own screen and don't use the deck
                guard selection != .smart(.duplicates) else { return }
                viewModel.openDeck(selection)
            } else if newPath.isEmpty, !oldPath.isEmpty {
                if oldPath.last != .smart(.duplicates) {
                    viewModel.closeDeck()
                }
                viewModel.refreshSmartCounts()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Pick up permission changes made in iOS Settings
            if phase == .active {
                viewModel.reloadIfAccessChanged()
            }
        }
        .overlay(alignment: .top) {
            if let milestone = analytics.newlyEarnedMilestone {
                MilestoneToast(milestone: milestone) {
                    analytics.acknowledgeMilestone()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: analytics.newlyEarnedMilestone)
        .sheet(isPresented: $showTips, onDismiss: SwipeTutorialManager.markAsSeen) {
            SwipeTipsView()
        }
        .fullScreenCover(isPresented: $viewModel.sessionTargetReached) {
            SessionSummaryView(
                storageSaved: viewModel.sessionStorageSaved,
                reviewCount: viewModel.sessionReviewCount,
                trashCount: trashManager.trashedAssets.count,
                onContinue: {
                    viewModel.startNewSession()
                },
                onReviewTrash: {
                    viewModel.startNewSession()
                    appState.activeTab = .trash
                }
            )
        }
    }

    // MARK: - Toolbar

    private var modePicker: some View {
        Picker("Review Mode", selection: $viewModel.reviewMode) {
            ForEach(ReviewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }

    private var undoButton: some View {
        Button {
            viewModel.undoLastAction()
        } label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
        }
        .disabled(!viewModel.canUndo)
        .keyboardShortcut("z", modifiers: .command)
    }

    // MARK: - Category Menu

    private var categoryMenu: some View {
        Menu {
            Picker(
                "Show",
                selection: Binding(
                    get: { viewModel.libraryCategory },
                    set: { viewModel.selectLibraryCategory($0) }
                )
            ) {
                ForEach(PhotoCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category)
                }
            }

            Picker(
                "From",
                selection: Binding(
                    get: { viewModel.yearFilter },
                    set: { viewModel.selectYear($0) }
                )
            ) {
                Label("Any Time", systemImage: "calendar").tag(Int?.none)
                ForEach(viewModel.availableYears, id: \.self) { year in
                    Text(String(year)).tag(Int?.some(year))
                }
            }
            .pickerStyle(.menu)
        } label: {
            HStack(spacing: AppSpacing.xxs) {
                Text(viewModel.libraryCategory.rawValue)
                    .font(.headline)
                if let year = viewModel.yearFilter {
                    Text("· \(String(year))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .contentShape(Rectangle())
        }
        .onAppear { viewModel.loadAvailableYearsIfNeeded() }
        .accessibilityLabel("Showing \(viewModel.libraryCategory.rawValue)\(viewModel.yearFilter.map { " from \($0)" } ?? "")")
        .accessibilityHint("Choose which photos to review")
    }
}
