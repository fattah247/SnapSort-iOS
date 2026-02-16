//
//  MainTabView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import SwiftUI
import Foundation
import Photos
import CoreData
import OSLog

struct MainTabView: View {
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var analytics: CoreDataAnalyticsService
    @EnvironmentObject var hapticService: HapticService
    @EnvironmentObject var photoService: PhotoLibraryService
    @EnvironmentObject var bookmarkManager: CoreDataBookmarkManager
    @EnvironmentObject var trashManager: CoreDataTrashManager

    @EnvironmentObject var settings: SettingsViewModel

    // Smart analysis services (passed from App)
    let smartCategoryService: SmartCategoryService?
    let analysisService: PhotoAnalysisService?
    let peopleService: PeopleService?

    init(
        smartCategoryService: SmartCategoryService? = nil,
        analysisService: PhotoAnalysisService? = nil,
        peopleService: PeopleService? = nil
    ) {
        self.smartCategoryService = smartCategoryService
        self.analysisService = analysisService
        self.peopleService = peopleService
    }

    var body: some View {
        TabView(selection: $appState.activeTab) {
            ReviewView(
                photoService: photoService,
                haptic: hapticService,
                analytics: analytics,
                bookmarkManager: bookmarkManager,
                trashManager: trashManager,
                settings: settings,
                smartCategoryService: smartCategoryService,
                analysisService: analysisService,
                peopleService: peopleService
            )
            .tabItem { Label("Review", systemImage: "photo") }
            .tag(AppStateManager.AppTab.review)

            DashboardView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(AppStateManager.AppTab.stats)

            BookmarksView()
                .tabItem { Label("Bookmarks", systemImage: "bookmark") }
                .tag(AppStateManager.AppTab.bookmarks)

            TrashView()
                .tabItem { Label("Trash", systemImage: "trash") }
                .tag(AppStateManager.AppTab.trash)

            SettingsView()
                .environmentObject(settings) // Pass settings viewModel to the SettingsView
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppStateManager.AppTab.settings)
        }
        .onOpenURL { url in
            appState.handleDeepLink(url)
        }
        .onChange(of: appState.deepLinkTarget) { oldValue, newValue in
            handleDeepLinkTarget(newValue)
        }

    }

    private func handleDeepLinkTarget(_ target: AppStateManager.DeepLinkTarget?) {
        guard let target else { return }

        switch target {
        case .review(let id):
            if let asset = fetchAsset(for: id) {
                presentPhotoDetail(asset)
            }
        case .trash(let id):
            if let asset = fetchAsset(for: id) {
                presentTrashDetail(asset)
            }
        case .stats(let id):
            if let asset = fetchAsset(for: id) {
                presentStatsDetail(asset)
            }
        case .bookmarks(let id):
            if let asset = fetchAsset(for: id) {
                presentBookmarksDetail(asset)
            }
        case .settings(let id):
            if let asset = fetchAsset(for: id) {
                presentSettingsDetail(asset)
            }
        }
    }

    private func fetchAsset(for identifier: String) -> PHAsset? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return result.firstObject
    }

    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController
        else { return nil }
        var vc = rootVC
        while let presented = vc.presentedViewController {
            vc = presented
        }
        return vc
    }

    private func presentPhotoDetail(_ asset: PHAsset) {
        let detailView = PhotoDetailView(asset: asset)
            .environmentObject(photoService)
            .environmentObject(bookmarkManager)

        let hostingController = UIHostingController(rootView: detailView)
        hostingController.modalPresentationStyle = .fullScreen

        guard let topVC = topViewController() else {
            AppLogger.general.error("Failed to get root view controller for photo detail")
            return
        }

        topVC.present(hostingController, animated: true)
    }

    private func presentTrashDetail(_ asset: PHAsset) {
        let trashDetailView = TrashDetailView(asset: asset)
            .environmentObject(trashManager)
            .environmentObject(photoService)
            .environmentObject(hapticService)

        let hostingController = UIHostingController(rootView: trashDetailView)
        hostingController.modalPresentationStyle = .formSheet

        guard let topVC = topViewController() else {
            AppLogger.general.error("Failed to get root view controller for trash detail")
            return
        }

        topVC.present(hostingController, animated: true)
    }

    private func presentStatsDetail(_ asset: PHAsset) {
        let detailView = DashboardView()
            .environmentObject(analytics)
            .environmentObject(settings)

        let hostingController = UIHostingController(rootView: detailView)
        hostingController.modalPresentationStyle = .fullScreen

        guard let topVC = topViewController() else {
            AppLogger.general.error("Failed to get root view controller for stats detail")
            return
        }

        topVC.present(hostingController, animated: true)
    }

    private func presentBookmarksDetail(_ asset: PHAsset) {
        let detailView = BookmarksView()
            .environmentObject(photoService)
            .environmentObject(bookmarkManager)
            .environmentObject(hapticService)

        let hostingController = UIHostingController(rootView: detailView)
        hostingController.modalPresentationStyle = .fullScreen

        guard let topVC = topViewController() else {
            AppLogger.general.error("Failed to get root view controller for bookmarks detail")
            return
        }

        topVC.present(hostingController, animated: true)
    }

    private func presentSettingsDetail(_ asset: PHAsset) {
        let detailView = PhotoDetailView(asset: asset)
            .environmentObject(photoService)
            .environmentObject(bookmarkManager)

        let hostingController = UIHostingController(rootView: detailView)
        hostingController.modalPresentationStyle = .fullScreen

        guard let topVC = topViewController() else {
            AppLogger.general.error("Failed to get root view controller for settings detail")
            return
        }

        topVC.present(hostingController, animated: true)
    }


    struct TrashDetailView: View {
        let asset: PHAsset
        @EnvironmentObject var trashManager: CoreDataTrashManager
        @EnvironmentObject var photoService: PhotoLibraryService
        @Environment(\.dismiss) var dismiss
        @State private var image: UIImage?
        @State private var showDeleteConfirmation = false

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                VStack(spacing: AppSpacing.sectionSpacing) {
                    Button(action: restoreAsset) {
                        Label("Restore", systemImage: "arrow.uturn.backward.circle.fill")
                            .font(AppTypography.button)
                            .foregroundColor(.white)
                            .padding(AppSpacing.sm)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Permanently", systemImage: "trash.circle.fill")
                            .font(AppTypography.button)
                            .foregroundColor(.white)
                            .padding(AppSpacing.sm)
                            .background(AppColors.danger)
                            .clipShape(Capsule())
                    }
                    .confirmationDialog("Confirm Deletion", isPresented: $showDeleteConfirmation) {
                        Button("Delete Forever", role: .destructive) {
                            deleteAssetPermanently()
                        }
                    }
                }
                .padding()
            }
            .task { await loadImage() }
            .navigationTitle("Trash Detail")
            .navigationBarTitleDisplayMode(.inline)
        }

        private func loadImage() async {
            let screenScale = UIScreen.main.scale
            let screenSize = UIScreen.main.bounds.size
            let targetSize = CGSize(
                width: screenSize.width * screenScale,
                height: screenSize.height * screenScale
            )
            image = await photoService.loadImage(for: asset, size: targetSize)
        }

        private func restoreAsset() {
            trashManager.restoreFromTrash(assetIdentifier: asset.localIdentifier)
            dismiss()
        }

        private func deleteAssetPermanently() {
            Task {
                do {
                    try await photoService.deleteAssets([asset])
                    trashManager.emptyTrash()
                    dismiss()
                } catch {
                    AppLogger.general.error("Failed to delete asset permanently: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}
