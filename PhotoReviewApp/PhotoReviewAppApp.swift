//
//  PhotoReviewAppApp.swift
//  PhotoReviewApp
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
struct PhotoReviewApp: App {
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

    // Determine if onboarding is needed
    private var needsOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

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

        let sharedSettingsViewModel = SettingsViewModel(
            settingsStore: UserDefaultsSettingsStore(),
            trashManager: sharedTrashManager,
            notificationService: sharedNotificationService
        )

        // Analysis services
        let sharedAnalysisCacheManager = AnalysisCacheManager(context: context)
        let sharedPeopleService = PeopleService()
        let sharedAnalysisService = PhotoAnalysisService(cacheManager: sharedAnalysisCacheManager)
        let sharedSmartCategoryService = SmartCategoryService(
            analysisService: sharedAnalysisService,
            cacheManager: sharedAnalysisCacheManager,
            peopleService: sharedPeopleService,
            photoService: sharedPhotoService
        )
        let sharedBackgroundScheduler = BackgroundAnalysisScheduler(
            analysisService: sharedAnalysisService,
            cacheManager: sharedAnalysisCacheManager,
            peopleService: sharedPeopleService,
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
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if needsOnboarding {
                    NavigationStack {
                        OnboardingView()
                            .onDisappear {
                                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                            }
                    }
                } else {
                    MainTabView(
                        smartCategoryService: smartCategoryService,
                        analysisService: analysisService,
                        peopleService: peopleService
                    )
                }
            }
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
                appState.configureServices(
                    photoService: photoService,
                    notificationService: notificationService
                )
                // Schedule background analysis for tonight
                backgroundAnalysisScheduler.scheduleBackgroundAnalysis()
            }
        }
    }
}
