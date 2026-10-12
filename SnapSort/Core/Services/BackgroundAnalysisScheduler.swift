//
//  BackgroundAnalysisScheduler.swift
//  SnapSort
//
//  Schedules background photo analysis using BGProcessingTask at 2-4 AM
//

import BackgroundTasks
import Photos
import OSLog

final class BackgroundAnalysisScheduler {
    private let analysisService: PhotoAnalysisService
    private let photoService: any PhotoLibraryServiceProtocol

    static let taskIdentifier = Constants.Analysis.backgroundTaskIdentifier

    /// Stored so the expiration handler can cancel the awaiting task too
    private var completionTask: Task<Void, Never>?

    init(
        analysisService: PhotoAnalysisService,
        photoService: any PhotoLibraryServiceProtocol
    ) {
        self.analysisService = analysisService
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

        // Handle expiration — cancel both the analysis and the completion waiter
        task.expirationHandler = { [weak self] in
            analysisTask.cancel()
            self?.completionTask?.cancel()
            AppLogger.analysis.info("Background analysis expired — will resume next night")
        }

        // Store so the expiration handler can cancel it; awaits analysis then marks done
        completionTask = Task {
            await analysisTask.value
            task.setTaskCompleted(success: true)
            AppLogger.analysis.info("Background analysis completed successfully")
        }
    }

    @MainActor
    private func performBackgroundAnalysis() async {
        // A foreground scan already covers this
        guard !analysisService.analysisProgress.isScanning else { return }
        AppLogger.analysis.info("Starting background analysis at \(Date(), privacy: .public)")
        await analysisService.scanLibrary(photoService: photoService)
    }
}
