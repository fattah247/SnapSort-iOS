//
//  SnapSortApp.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 28/01/25.
//
import SwiftUI
import Foundation
import CoreData
import Photos
import BackgroundTasks
import OSLog

@main
struct SnapSortApp: App {
    @StateObject private var appState = AppStateManager()
    @StateObject private var hapticService = HapticService()
    @StateObject private var dataManager = CoreDataManager.shared

    @StateObject private var photoService: PhotoLibraryService
    @StateObject private var notificationService: NotificationService
    @StateObject private var analyticsService: CoreDataAnalyticsService
    @StateObject private var bookmarkManager: CoreDataBookmarkManager
    @StateObject private var trashManager: CoreDataTrashManager
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var analysisService: PhotoAnalysisService

    // Non-observable services (no @StateObject needed)
    private let analysisCacheManager: AnalysisCacheManager
    private let peopleService: PeopleService
    private let smartCategoryService: SmartCategoryService
    private let backgroundAnalysisScheduler: BackgroundAnalysisScheduler

    // Observed, so finishing onboarding swaps the root view
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        let context = CoreDataManager.shared.viewContext

        let sharedPhotoService = PhotoLibraryService()
        let sharedNotificationService = NotificationService()

        let sharedAnalyticsService = CoreDataAnalyticsService(context: context)

        let sharedBookmarkManager = CoreDataBookmarkManager(
            context: context,
            photoService: sharedPhotoService
        )

        let sharedTrashManager = CoreDataTrashManager(
            context: context,
            photoService: sharedPhotoService
        )
        sharedAnalyticsService.prepareSpaceClearedMigration(
            trashedIdentifiers: sharedTrashManager.storedIdentifiers
        )

        let sharedSettingsViewModel = SettingsViewModel(
            settingsStore: UserDefaultsSettingsStore(),
            notificationService: sharedNotificationService
        )

        // Analysis services
        let sharedAnalysisCacheManager = AnalysisCacheManager(context: context)
        let sharedSimilarShots = SimilarShotsStore()
        let sharedPeopleService = PeopleService()
        let sharedAnalysisService = PhotoAnalysisService(
            cacheManager: sharedAnalysisCacheManager,
            similarShots: sharedSimilarShots
        )
        let sharedSmartCategoryService = SmartCategoryService(
            cacheManager: sharedAnalysisCacheManager,
            peopleService: sharedPeopleService,
            similarShots: sharedSimilarShots
        )
        let sharedBackgroundScheduler = BackgroundAnalysisScheduler(
            analysisService: sharedAnalysisService,
            photoService: sharedPhotoService
        )

        _photoService = StateObject(wrappedValue: sharedPhotoService)
        _notificationService = StateObject(wrappedValue: sharedNotificationService)
        _analyticsService = StateObject(wrappedValue: sharedAnalyticsService)
        _bookmarkManager = StateObject(wrappedValue: sharedBookmarkManager)
        _trashManager = StateObject(wrappedValue: sharedTrashManager)
        _settingsViewModel = StateObject(wrappedValue: sharedSettingsViewModel)
        _analysisService = StateObject(wrappedValue: sharedAnalysisService)

        self.analysisCacheManager = sharedAnalysisCacheManager
        self.peopleService = sharedPeopleService
        self.smartCategoryService = sharedSmartCategoryService
        self.backgroundAnalysisScheduler = sharedBackgroundScheduler

        // Register background task
        sharedBackgroundScheduler.registerBackgroundTask()

        Self.applyRoundedNavigationTitles()
    }

    /// SwiftUI's `.fontDesign` doesn't reach navigation bar titles, so set them here
    private static func applyRoundedNavigationTitles() {
        func rounded(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.preferredFont(forTextStyle: style)
            let weighted = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
            guard let descriptor = weighted.fontDescriptor.withDesign(.rounded) else { return weighted }
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: base.pointSize))
        }
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: rounded(.largeTitle, weight: .bold)]
        appearance.titleTextAttributes = [.font: rounded(.headline, weight: .semibold)]

        // Alerts, dialogs and share sheets take their tint from the window
        UIWindow.appearance().tintColor = UIColor(named: "AccentColor")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView(
                        smartCategoryService: smartCategoryService,
                        analysisService: analysisService,
                        peopleService: peopleService
                    )
                    .transition(.opacity)
                } else {
                    OnboardingView {
                        withAnimation {
                            hasCompletedOnboarding = true
                        }
                    }
                    .transition(.opacity)
                }
            }
            .fontDesign(.rounded)
            .tint(AppColors.brand)
            // Inject all necessary environment objects.
            .environmentObject(appState)
            .environmentObject(photoService)
            .environmentObject(hapticService)
            .environmentObject(notificationService)
            .environmentObject(settingsViewModel)
            .environmentObject(analyticsService)
            .environmentObject(bookmarkManager)
            .environmentObject(trashManager)
            .environmentObject(analysisService)
            .environment(\.managedObjectContext, dataManager.viewContext)
            .onAppear {
                // Schedule background analysis for tonight
                backgroundAnalysisScheduler.scheduleBackgroundAnalysis()
            }
        }
    }
}
