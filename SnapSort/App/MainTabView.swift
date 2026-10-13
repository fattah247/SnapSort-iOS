//
//  MainTabView.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import SwiftUI
import Photos

struct MainTabView: View {
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var analytics: CoreDataAnalyticsService
    @EnvironmentObject var haptics: Haptics
    @EnvironmentObject var photoService: PhotoLibraryService
    @EnvironmentObject var bookmarkManager: CoreDataBookmarkManager
    @EnvironmentObject var trashManager: CoreDataTrashManager
    @EnvironmentObject var settings: SettingsViewModel

    // Smart analysis services (passed from App)
    let smartCategoryService: SmartCategoryService?
    let analysisService: PhotoAnalysisService?
    let peopleService: PeopleService?

    @State private var deepLinkAsset: PHAsset?
    @Environment(\.scenePhase) private var scenePhase

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
            Tab("Review", systemImage: "rectangle.stack", value: AppStateManager.AppTab.review) {
                ReviewView(
                    photoService: photoService,
                    haptics: haptics,
                    analytics: analytics,
                    bookmarkManager: bookmarkManager,
                    trashManager: trashManager,
                    settings: settings,
                    smartCategoryService: smartCategoryService,
                    analysisService: analysisService,
                    peopleService: peopleService
                )
            }

            Tab("Stats", systemImage: "chart.bar", value: AppStateManager.AppTab.stats) {
                DashboardView()
            }

            Tab("Bookmarks", systemImage: "bookmark", value: AppStateManager.AppTab.bookmarks) {
                BookmarksView()
            }

            Tab("Trash", systemImage: "trash", value: AppStateManager.AppTab.trash) {
                TrashView()
            }
            .badge(trashManager.trashedAssets.count)

            Tab("Settings", systemImage: "gearshape", value: AppStateManager.AppTab.settings) {
                SettingsView()
            }
        }
        .onOpenURL { url in
            appState.handleDeepLink(url)
        }
        .onChange(of: appState.deepLinkTarget) { _, target in
            handleDeepLinkTarget(target)
        }
        .sheet(item: $deepLinkAsset) { asset in
            PhotoDetailView(asset: asset)
        }
        .task {
            // Warm up now so the first swipe's feedback isn't late
            haptics.prepare()
            // Let the first deck load before analysis starts competing for the CPU
            try? await Task.sleep(for: .seconds(3))
            startScanIfAllowed()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            haptics.prepare()
            // Pick up photos taken while the app was in the background
            startScanIfAllowed()
        }
    }

    private func startScanIfAllowed() {
        guard PhotoLibraryAccess.isGranted else { return }
        analysisService?.startBackgroundScan(photoService: photoService)

        Task {
            await analytics.finishSpaceClearedMigration { identifiers in
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                var bytes: Int64 = 0
                for asset in assets.objects(at: IndexSet(integersIn: 0..<assets.count)) {
                    bytes += await asset.fetchFileSize()
                }
                return bytes
            }
        }
    }

    /// The tab switch happens in `AppStateManager`; links with a photo ID also open it.
    private func handleDeepLinkTarget(_ target: AppStateManager.DeepLinkTarget?) {
        guard let target else { return }
        defer { appState.deepLinkTarget = nil }

        switch target {
        case .review(let id), .trash(let id), .bookmarks(let id):
            deepLinkAsset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        case .stats, .settings:
            break
        }
    }
}
