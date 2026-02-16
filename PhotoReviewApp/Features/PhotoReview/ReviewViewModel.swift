//
//  ReviewViewModel.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import SwiftUI
import Photos
import CoreData
import OSLog

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var state: ViewState = .idle
    @Published var showSettings = false
    @Published var showDeleteAlert = false
    @Published var pendingDeletePhoto: Photo?
    @Published var selectedCategory: CategorySelection = .library(.all)
    @Published var reviewMode: ReviewMode = .library

    // Session tracking
    @Published var sessionStorageSaved: Int64 = 0
    @Published var sessionReviewCount: Int = 0
    @Published var sessionTargetReached = false

    // Smart category state
    @Published var smartCategoryCounts: [SmartCategory: Int] = [:]
    @Published var peopleAlbums: [PersonAlbum] = []
    @Published var isInSmartSwipeMode = false

    private let settings: SettingsViewModel
    private let photoService: any PhotoLibraryServiceProtocol
    private let haptic: any HapticServiceProtocol
    private let analytics: any AnalyticsServiceProtocol
    private let bookmarkManager: any BookmarkManagerProtocol
    private let trashManager: any TrashManagerProtocol
    let smartCategoryService: SmartCategoryService?
    let analysisService: PhotoAnalysisService?
    let peopleService: PeopleService?
    private var currentTask: Task<Void, Never>?

    /// Fixed batch size for loading photos
    private let batchSize = 10

    // Track reviewed photo IDs to avoid showing them again in this session
    private var reviewedPhotoIds = Set<String>()

    var storageTarget: Int64 {
        settings.storageTarget
    }

    var storageProgress: Double {
        guard storageTarget > 0 else { return 0 }
        return min(Double(sessionStorageSaved) / Double(storageTarget), 1.0)
    }

    init(
        photoService: any PhotoLibraryServiceProtocol,
        haptic: any HapticServiceProtocol,
        analytics: any AnalyticsServiceProtocol,
        bookmarkManager: any BookmarkManagerProtocol,
        trashManager: any TrashManagerProtocol,
        settings: SettingsViewModel,
        smartCategoryService: SmartCategoryService? = nil,
        analysisService: PhotoAnalysisService? = nil,
        peopleService: PeopleService? = nil
    ) {
        self.photoService = photoService
        self.haptic = haptic
        self.analytics = analytics
        self.settings = settings
        self.bookmarkManager = bookmarkManager
        self.trashManager = trashManager
        self.smartCategoryService = smartCategoryService
        self.analysisService = analysisService
        self.peopleService = peopleService
    }

    func loadInitialPhotos() async {
        cancelCurrentTask()
        currentTask = Task {
            await processPhotos()
        }
    }

    // MARK: - Library Category Selection

    func selectLibraryCategory(_ category: PhotoCategory) {
        let newSelection = CategorySelection.library(category)
        guard newSelection != selectedCategory else { return }
        selectedCategory = newSelection
        reviewMode = .library
        isInSmartSwipeMode = false
        reviewedPhotoIds.removeAll()
        Task { await loadInitialPhotos() }
    }

    // MARK: - Smart Category Selection

    func selectSmartCategory(_ category: SmartCategory) {
        selectedCategory = .smart(category)
        isInSmartSwipeMode = true
        reviewedPhotoIds.removeAll()
        Task { await loadInitialPhotos() }
    }

    func selectPerson(_ person: PersonAlbum) {
        selectedCategory = .person(id: person.id, name: person.name)
        isInSmartSwipeMode = true
        reviewedPhotoIds.removeAll()
        Task { await loadInitialPhotos() }
    }

    func exitSmartSwipeMode() {
        isInSmartSwipeMode = false
        selectedCategory = .library(.all)
        reviewedPhotoIds.removeAll()
        state = .idle
    }

    // MARK: - Smart Data Loading

    func loadSmartData() {
        guard let smartCategoryService, let peopleService else { return }

        Task {
            let counts = smartCategoryService.getCategoryCounts()
            let albums = peopleService.fetchPeopleAlbums()

            await MainActor.run {
                self.smartCategoryCounts = counts
                self.peopleAlbums = albums
            }
        }
    }

    /// Loads more photos to append to the existing queue
    func loadMorePhotos() async {
        cancelCurrentTask()
        currentTask = Task {
            await processPhotos(appendToExisting: true)
        }
    }

    /// Starts a new session after ad is watched
    func startNewSession() {
        sessionStorageSaved = 0
        sessionReviewCount = 0
        sessionTargetReached = false
        Task { await loadInitialPhotos() }
    }

    // MARK: - Photo Processing

    private func processPhotos(appendToExisting: Bool = false) async {
        if !appendToExisting {
            state = .loading
        }

        let limit = batchSize

        // Build exclusion set: reviewed + bookmarked + trashed
        let bookmarkedIds = Set(bookmarkManager.bookmarkedAssets.map { $0.localIdentifier })
        let trashedIds = Set(trashManager.trashedAssets.map { $0.localIdentifier })
        let excludedIds = reviewedPhotoIds.union(bookmarkedIds).union(trashedIds)

        do {
            let assetsToProcess: [PHAsset]

            switch selectedCategory {
            case .library(let category):
                assetsToProcess = try await fetchLibraryAssets(
                    category: category,
                    limit: limit,
                    excludedIds: excludedIds,
                    bookmarkedIds: bookmarkedIds,
                    trashedIds: trashedIds
                )

            case .smart(let category):
                assetsToProcess = await fetchSmartAssets(
                    category: category,
                    limit: limit,
                    excludedIds: excludedIds
                )

            case .person(let id, let name):
                assetsToProcess = fetchPersonAssets(
                    personId: id,
                    personName: name,
                    limit: limit,
                    excludedIds: excludedIds
                )
            }

            if assetsToProcess.isEmpty {
                if !appendToExisting {
                    state = .loaded([])
                }
                return
            }

            await processAndLoadPhotos(assetsToProcess, sortOption: settings.sortOption, append: appendToExisting)

        } catch {
            if !appendToExisting {
                state = .error(error)
            }
        }
    }

    // MARK: - Library Asset Fetching (existing logic)

    private func fetchLibraryAssets(
        category: PhotoCategory,
        limit: Int,
        excludedIds: Set<String>,
        bookmarkedIds: Set<String>,
        trashedIds: Set<String>
    ) async throws -> [PHAsset] {
        let sortOption = settings.sortOption

        if sortOption == .random {
            if category == .all {
                var result = await photoService.fetchRandomAssets(
                    count: limit,
                    excluding: excludedIds
                )
                if result.isEmpty && !reviewedPhotoIds.isEmpty {
                    AppLogger.general.info("Clearing review history - retrying random fetch")
                    reviewedPhotoIds.removeAll()
                    let retryExcluded = bookmarkedIds.union(trashedIds)
                    result = await photoService.fetchRandomAssets(
                        count: limit,
                        excluding: retryExcluded
                    )
                }
                return result
            } else {
                let excluded = excludedIds
                var result = await Task.detached {
                    PhotoCategoryService.shared.fetchRandomAssets(
                        category: category,
                        count: limit,
                        excluding: excluded
                    )
                }.value
                if result.isEmpty && !reviewedPhotoIds.isEmpty {
                    AppLogger.general.info("Clearing review history - retrying category random fetch")
                    reviewedPhotoIds.removeAll()
                    let retryExcluded = bookmarkedIds.union(trashedIds)
                    result = await Task.detached {
                        PhotoCategoryService.shared.fetchRandomAssets(
                            category: category,
                            count: limit,
                            excluding: retryExcluded
                        )
                    }.value
                }
                return result
            }
        } else {
            let fetchLimit = max(limit * 3, 50)

            let allAssets: [PHAsset]
            if category == .all {
                allAssets = try await photoService.fetchAssets(options: .init(
                    limit: fetchLimit,
                    sortDescriptors: sortOption.sortDescriptors
                ))
            } else {
                let sortDescriptors = sortOption.sortDescriptors
                allAssets = await Task.detached {
                    PhotoCategoryService.shared.fetchAssets(
                        category: category,
                        limit: fetchLimit,
                        sortDescriptors: sortDescriptors
                    )
                }.value
            }

            var available = allAssets.filter { !excludedIds.contains($0.localIdentifier) }

            if available.isEmpty && !allAssets.isEmpty {
                AppLogger.general.info("Clearing review history - all photos in pool were reviewed")
                reviewedPhotoIds.removeAll()
                let retryExcluded = bookmarkedIds.union(trashedIds)
                available = allAssets.filter { !retryExcluded.contains($0.localIdentifier) }
            }

            return Array(available.prefix(limit))
        }
    }

    // MARK: - Smart Asset Fetching

    private func fetchSmartAssets(
        category: SmartCategory,
        limit: Int,
        excludedIds: Set<String>
    ) async -> [PHAsset] {
        guard let smartCategoryService else { return [] }
        return await smartCategoryService.fetchAssets(
            category: category,
            limit: limit,
            excluding: excludedIds,
            sortOption: settings.sortOption
        )
    }

    // MARK: - Person Asset Fetching

    private func fetchPersonAssets(
        personId: String,
        personName: String,
        limit: Int,
        excludedIds: Set<String>
    ) -> [PHAsset] {
        guard let smartCategoryService else { return [] }
        let person = PersonAlbum(id: personId, name: personName, assetCount: 0, keyAsset: nil)
        return smartCategoryService.fetchAssetsForPerson(
            person,
            limit: limit,
            excluding: excludedIds,
            sortOption: settings.sortOption
        )
    }

    // MARK: - Photo Loading

    private func processAndLoadPhotos(_ assets: [PHAsset], sortOption: PhotoSortOption, append: Bool = false) async {
        let maxConcurrent = 5
        let photos = await withTaskGroup(of: Photo?.self) { group in
            var result = [Photo]()
            var iterator = assets.makeIterator()

            for _ in 0..<min(maxConcurrent, assets.count) {
                if let asset = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        return await self.processAsset(asset)
                    }
                }
            }

            for await photo in group {
                if let photo = photo {
                    result.append(photo)
                }
                if let asset = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        return await self.processAsset(asset)
                    }
                }
            }
            return result
        }

        for photo in photos {
            reviewedPhotoIds.insert(photo.id)
        }

        let newPhotos = sortOption == .random ? photos.shuffled() : photos

        if append, case .loaded(let existing) = state {
            state = .loaded(existing + newPhotos)
        } else {
            state = .loaded(newPhotos)
        }
    }

    /// Resets the review history to allow seeing all photos again
    func resetReviewHistory() {
        reviewedPhotoIds.removeAll()
    }

    private func processAsset(_ asset: PHAsset) async -> Photo? {
        async let imageTask = photoService.loadImage(
            for: asset,
            size: CGSize(width: 800, height: 800)
        )
        async let fileSizeTask = asset.fetchFileSize()

        guard let image = await imageTask else { return nil }
        let fileSize = await fileSizeTask

        // Attach cached analysis result if available
        let analysisResult = analysisService?.cacheManager.getCachedResult(assetIdentifier: asset.localIdentifier)

        return Photo(
            id: asset.localIdentifier,
            image: image,
            creationDate: asset.creationDate,
            fileSize: fileSize,
            analysisResult: analysisResult
        )
    }

    // MARK: - Swipe Handling

    func handleSwipe(_ direction: SwipeDirection, for photo: Photo) {
        analytics.trackReview()
        sessionReviewCount += 1

        switch direction {
        case .right:
            bookmarkManager.toggleBookmark(assetIdentifier: photo.id)
            analytics.trackBookmark()
            haptic.notify(.success)
            removePhoto(photo)

        case .left:
            if settings.showDeletionConfirmation {
                pendingDeletePhoto = photo
                showDeleteAlert = true
            } else {
                performDeletion(photo)
            }
        }

        // Auto-load more photos when queue is getting low
        if case .loaded(let photos) = state, photos.count <= 3 && !sessionTargetReached {
            Task { await loadMorePhotos() }
        }
    }

    private func performDeletion(_ photo: Photo) {
        trashManager.addToTrash(assetIdentifier: photo.id)
        analytics.trackDeletion(fileSize: photo.fileSize)
        sessionStorageSaved += photo.fileSize
        haptic.notify(.warning)
        removePhoto(photo)

        // Check if storage target reached
        if sessionStorageSaved >= storageTarget {
            sessionTargetReached = true
        }
    }

    private func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func removePhoto(_ photo: Photo) {
        withAnimation(.spring()) {
            state.removePhoto(photo)
        }
    }

    func confirmDeletion(of photo: Photo?) {
        guard let p = photo else { return }
        pendingDeletePhoto = nil
        showDeleteAlert = false
        performDeletion(p)

        // Auto-load more if queue low
        if case .loaded(let photos) = state, photos.count <= 3 && !sessionTargetReached {
            Task { await loadMorePhotos() }
        }
    }

    func skipPhoto(_ photo: Photo) {
        guard case .loaded(var photos) = state else { return }

        if let index = photos.firstIndex(where: { $0.id == photo.id }) {
            let skippedPhoto = photos.remove(at: index)
            photos.append(skippedPhoto)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                state = .loaded(photos)
            }
            haptic.impact(.light)
        }
    }

    // MARK: - Delete All for Person

    func deleteAllPhotosForPerson(_ person: PersonAlbum) {
        guard let peopleService else { return }
        Task {
            let assets = peopleService.fetchAllAssets(for: person)
            for asset in assets {
                trashManager.addToTrash(assetIdentifier: asset.localIdentifier)
            }
            var totalSize: Int64 = 0
            for asset in assets {
                totalSize += await asset.fetchFileSize()
            }
            analytics.trackDeletion(fileSize: totalSize)
            sessionStorageSaved += totalSize
            haptic.notify(.warning)
        }
    }
}

// MARK: - ViewState

extension ReviewViewModel {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded([Photo])
        case error(Error)

        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading):
                return true
            case (.loaded(let lhsPhotos), .loaded(let rhsPhotos)):
                return lhsPhotos.map { $0.id } == rhsPhotos.map { $0.id }
            case (.error, .error):
                return true
            default:
                return false
            }
        }

        mutating func removePhoto(_ photo: Photo) {
            guard case .loaded(var photos) = self else { return }
            photos.removeAll { $0.id == photo.id }
            self = .loaded(photos)
        }
    }
}
