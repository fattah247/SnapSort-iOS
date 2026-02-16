//
//  BackgroundAnalysisScheduler.swift
//  PhotoReviewApp
//
//  Schedules background photo analysis using BGProcessingTask at 2-4 AM
//

import BackgroundTasks
import Photos
import OSLog

final class BackgroundAnalysisScheduler {
    private let analysisService: PhotoAnalysisService
    private let cacheManager: AnalysisCacheManager
    private let peopleService: PeopleService
    private let photoService: any PhotoLibraryServiceProtocol

    static let taskIdentifier = Constants.Analysis.backgroundTaskIdentifier

    init(
        analysisService: PhotoAnalysisService,
        cacheManager: AnalysisCacheManager,
        peopleService: PeopleService,
        photoService: any PhotoLibraryServiceProtocol
    ) {
        self.analysisService = analysisService
        self.cacheManager = cacheManager
        self.peopleService = peopleService
        self.photoService = photoService
    }

    // MARK: - Registration

    /// Call this in app init BEFORE application finishes launching
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self?.handleBackgroundTask(processingTask)
        }
        AppLogger.analysis.info("Registered background analysis task")
    }

    // MARK: - Scheduling

    func scheduleBackgroundAnalysis() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)

        // Schedule for next 2:00 AM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 2
        components.minute = 0

        var scheduledDate = calendar.date(from: components) ?? Date()

        // If 2 AM has already passed today, schedule for tomorrow
        if scheduledDate <= Date() {
            scheduledDate = calendar.date(byAdding: .day, value: 1, to: scheduledDate) ?? Date()
        }

        request.earliestBeginDate = scheduledDate
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false

        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.analysis.info("Scheduled background analysis for \(scheduledDate, privacy: .public)")
        } catch {
            AppLogger.analysis.error("Failed to schedule background analysis: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Task Handling

    private func handleBackgroundTask(_ task: BGProcessingTask) {
        // Schedule next occurrence immediately
        scheduleBackgroundAnalysis()

        let analysisTask = Task { @MainActor in
            await performBackgroundAnalysis()
        }

        // Handle expiration — clean cancel
        task.expirationHandler = {
            analysisTask.cancel()
            AppLogger.analysis.info("Background analysis expired — will resume next night")
        }

        // Run analysis
        Task {
            await analysisTask.value
            task.setTaskCompleted(success: true)
            AppLogger.analysis.info("Background analysis completed successfully")
        }
    }

    @MainActor
    private func performBackgroundAnalysis() async {
        AppLogger.analysis.info("Starting background analysis at \(Date(), privacy: .public)")

        do {
            // Fetch all photos
            let allAssets = try await photoService.fetchAssets(options: .init(
                limit: 0,
                sortDescriptors: [NSSortDescriptor(key: "creationDate", ascending: false)]
            ))

            // Find uncached assets
            let uncachedIds = cacheManager.getUncachedIdentifiers(
                from: allAssets.map { $0.localIdentifier }
            )

            let uncachedAssets = allAssets.filter { uncachedIds.contains($0.localIdentifier) }

            AppLogger.analysis.info("Background: \(uncachedAssets.count) photos to analyze")

            guard !uncachedAssets.isEmpty else { return }

            // Invalidate stale entries
            cacheManager.invalidateStaleEntries(assets: Array(allAssets.prefix(500)))

            // Process in batches
            let batchSize = Constants.Analysis.backgroundBatchSize
            for batchStart in stride(from: 0, to: uncachedAssets.count, by: batchSize) {
                try Task.checkCancellation()

                // Check thermal state — stop if device is too warm
                let thermal = ProcessInfo.processInfo.thermalState
                if thermal == .serious || thermal == .critical {
                    AppLogger.analysis.warning("Background analysis paused — thermal state: \(String(describing: thermal), privacy: .public)")
                    break
                }

                let batchEnd = min(batchStart + batchSize, uncachedAssets.count)
                let batch = Array(uncachedAssets[batchStart..<batchEnd])

                let _ = await analysisService.analyzeBatch(assets: batch)

                // Small delay between batches to be gentle on resources
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }

            // Run duplicate detection on analyzed photos
            let allIds = cacheManager.getAllCachedResults().map { $0.assetIdentifier }
            if allIds.count >= 2 {
                let smartCategoryService = SmartCategoryService(
                    analysisService: analysisService,
                    cacheManager: cacheManager,
                    peopleService: peopleService,
                    photoService: photoService
                )
                let _ = await smartCategoryService.findDuplicates(among: allIds)
            }

        } catch is CancellationError {
            AppLogger.analysis.info("Background analysis cancelled")
        } catch {
            AppLogger.analysis.error("Background analysis failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
