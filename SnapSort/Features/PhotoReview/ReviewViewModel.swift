//
//  ReviewViewModel.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import SwiftUI
import Photos
import OSLog

@MainActor
final class ReviewViewModel: ObservableObject {
    /// The review queue. `photos.first` is the card on top of the stack.
    @Published private(set) var state: ViewState = .idle
    /// The deck currently being reviewed (library filter, smart group, or person)
    @Published private(set) var selectedCategory: CategorySelection = .library(.all)
    /// Remembered library filter, restored when leaving a smart deck
    @Published private(set) var libraryCategory: PhotoCategory = .all
    /// Limits the library deck to one year, or nil for any time
    @Published private(set) var yearFilter: Int?
    @Published private(set) var availableYears: [Int] = []
    @Published var reviewMode: ReviewMode = .library

    // Session tracking
    @Published private(set) var sessionStorageSaved: Int64 = 0
    @Published private(set) var sessionReviewCount: Int = 0
    @Published var sessionTargetReached = false

    // Undo
    @Published private(set) var canUndo = false

    // Smart category state
    /// Photos left to review in each smart group (already trashed/bookmarked ones excluded)
    @Published private(set) var smartCategoryCounts: [SmartCategory: Int] = [:]
    /// Similar-shot sets that still have at least two unreviewed photos
    @Published private(set) var similarGroups: [SimilarShotGroup] = []
    @Published private(set) var peopleAlbums: [PersonAlbum] = []
    @Published private(set) var hasLoadedSmartCounts = false

    /// Indicates an append-load is in progress so the UI can show a loading indicator
    @Published private(set) var isLoadingMore = false

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
    private var upgradeTask: Task<Void, Never>?

    // MARK: - Constants

    private let batchSize = 10
    private let maxConcurrentImageLoads = 5
    private let autoLoadThreshold = 3
    private let maxUndoDepth = 20
    private let cardImageSize = CGSize(width: 600, height: 600)
    private let topCardImageSize = CGSize(width: 1200, height: 1200)

    // Track reviewed photo IDs to avoid showing them again in this session
    private var reviewedPhotoIds = Set<String>()
    private var assetLookup: [String: PHAsset] = [:]
    private var upgradedPhotoIds = Set<String>()
    private var undoStack: [ReviewedPhoto] = []

    private struct ReviewedPhoto {
        let photo: Photo
        let asset: PHAsset?
        let action: ReviewAction
    }

    var storageTarget: Int64 {
        settings.storageTarget
    }

    var storageProgress: Double {
        guard storageTarget > 0 else { return 0 }
        return min(Double(sessionStorageSaved) / Double(storageTarget), 1.0)
    }

    var requiresDeleteConfirmation: Bool {
        settings.showDeletionConfirmation
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

    deinit {
        currentTask?.cancel()
        upgradeTask?.cancel()
    }

    // MARK: - Loading

    /// Loads the deck only if nothing has been loaded yet (e.g. on first appear)
    func loadIfNeeded() {
        guard state == .idle else { return }
        reload()
    }

    func reload() {
        cancelCurrentTask()
        currentTask = Task {
            await processPhotos()
        }
    }

    /// Re-checks photo access, e.g. after returning from iOS Settings
    func reloadIfAccessChanged() {
        guard case .noAccess = state else { return }
        reload()
    }

    func requestPhotoAccess() async {
        let status = await photoService.requestAuthorization()
        if status == .authorized || status == .limited {
            reload()
        } else {
            state = .noAccess(status)
        }
    }

    /// Clears what's been seen this session and starts the deck again
    func startOver() {
        reviewedPhotoIds.removeAll()
        reload()
    }

    // MARK: - Deck Selection

    func selectYear(_ year: Int?) {
        guard year != yearFilter else { return }
        yearFilter = year
        activate(.library(libraryCategory))
    }

    func loadAvailableYearsIfNeeded() {
        guard availableYears.isEmpty else { return }
        Task {
            availableYears = await Task.detached { PhotoCategoryService.shared.availableYears() }.value
        }
    }

    func selectLibraryCategory(_ category: PhotoCategory) {
        libraryCategory = category
        guard selectedCategory != .library(category) else { return }
        activate(.library(category))
    }

    /// Shows the library deck, reloading only if another deck replaced it
    func showLibrary() {
        let selection = CategorySelection.library(libraryCategory)
        if selectedCategory != selection || state == .idle {
            activate(selection)
        }
    }

    /// Opens a smart group or person deck
    func openDeck(_ selection: CategorySelection) {
        activate(selection)
    }

    /// Leaves a smart deck. The library deck reloads lazily when shown again.
    func closeDeck() {
        cancelCurrentTask()
        selectedCategory = .library(libraryCategory)
        state = .idle
        clearUndo()
    }

    private func activate(_ selection: CategorySelection) {
        selectedCategory = selection
        reviewedPhotoIds.removeAll()
        assetLookup.removeAll()
        upgradedPhotoIds.removeAll()
        clearUndo()
        reload()
    }

    // MARK: - Smart Data Loading

    /// Refreshes counts and looks for photos that haven't been analyzed yet
    func loadSmartData() {
        refreshSmartCounts()
        analysisService?.startBackgroundScan(photoService: photoService)
    }

    /// Recomputes smart group counts from the analysis cache
    func refreshSmartCounts() {
        guard let smartCategoryService else { return }
        Task {
            let membership = await smartCategoryService.membership()
            let reviewed = reviewedElsewhereIDs
            var counts: [SmartCategory: Int] = [:]
            for (category, members) in membership {
                counts[category] = members.subtracting(reviewed).count
            }

            let groups = smartCategoryService.similarShots.groups().compactMap { group -> SimilarShotGroup? in
                let remaining = group.assetIdentifiers.filter { !reviewed.contains($0) }
                return remaining.count > 1 ? SimilarShotGroup(assetIdentifiers: remaining) : nil
            }
            counts[.duplicates] = groups.reduce(0) { $0 + $1.assetIdentifiers.count }

            smartCategoryCounts = counts
            similarGroups = groups
            peopleAlbums = peopleService?.fetchPeopleAlbums() ?? []
            hasLoadedSmartCounts = true
        }
    }

    /// Photos already decided on — bookmarked or waiting in the trash
    private var reviewedElsewhereIDs: Set<String> {
        Set(bookmarkManager.bookmarkedAssets.map(\.localIdentifier))
            .union(trashManager.trashedAssets.map(\.localIdentifier))
    }

    // MARK: - Similar Shots

    /// The photo worth keeping: sharpest, well exposed, and favorites win ties
    func suggestedKeeper(in group: SimilarShotGroup) async -> String? {
        guard let cache = analysisService?.cacheManager else { return group.assetIdentifiers.first }
        let scores = await cache.qualityScores(for: group.assetIdentifiers)
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: group.assetIdentifiers, options: nil)

        var best: (id: String, score: Float)?
        assets.enumerateObjects { asset, _, _ in
            let quality = scores[asset.localIdentifier] ?? (blur: 0.5, brightness: 0.5)
            let exposurePenalty = max(0, 0.2 - quality.brightness) * 2 + max(0, quality.brightness - 0.85) * 2
            var score = (1 - quality.blur) - exposurePenalty
            if asset.isFavorite { score += 1 }
            score += Float(asset.pixelWidth * asset.pixelHeight) / 1_000_000_000 // tiny tie-breaker
            if best == nil || score > best!.score {
                best = (asset.localIdentifier, score)
            }
        }
        return best?.id ?? group.assetIdentifiers.first
    }

    /// Keeps `keepers` and moves the rest of the set to the trash
    func resolveSimilarGroup(_ group: SimilarShotGroup, keeping keepers: Set<String>) {
        let toTrash = group.assetIdentifiers.filter { !keepers.contains($0) }
        if !toTrash.isEmpty {
            trashManager.addToTrash(assetIdentifiers: toTrash)
            for identifier in toTrash {
                analytics.record(.delete, assetIdentifier: identifier)
            }
            haptic.impact(.medium)
        }
        smartCategoryService?.similarShots.dismiss(group)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            similarGroups.removeAll { $0.id == group.id }
        }
        smartCategoryCounts[.duplicates] = similarGroups.reduce(0) { $0 + $1.assetIdentifiers.count }
    }

    /// Loads more photos to append to the bottom of the stack
    func loadMorePhotos() {
        guard !isLoadingMore else { return }
        isLoadingMore = true

        cancelCurrentTask()
        currentTask = Task {
            defer { isLoadingMore = false }
            await processPhotos(appendToExisting: true)
        }
    }

    /// Starts a new session after the session summary is dismissed
    func startNewSession() {
        sessionStorageSaved = 0
        sessionReviewCount = 0
        sessionTargetReached = false
        // Loading pauses while the summary is up — top the deck back up
        autoLoadMoreIfNeeded()
    }

    // MARK: - Photo Processing

    private func processPhotos(appendToExisting: Bool = false) async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            state = .noAccess(status)
            return
        }

        if !appendToExisting {
            state = .loading
        }

        let bookmarkedIds = Set(bookmarkManager.bookmarkedAssets.map { $0.localIdentifier })
        let trashedIds = Set(trashManager.trashedAssets.map { $0.localIdentifier })
        let excludedIds = reviewedPhotoIds.union(bookmarkedIds).union(trashedIds).union(queuedPhotoIds)

        // Overshoot: fetch more candidates than batchSize so we can skip
        // iCloud-only photos that fail to load and still fill the queue.
        let candidateLimit = batchSize * Constants.PhotoLoading.candidateOvershootMultiplier

        let assetsToProcess: [PHAsset]

        switch selectedCategory {
        case .library(let category):
            assetsToProcess = await fetchLibraryAssets(
                category: category,
                limit: candidateLimit,
                excludedIds: excludedIds,
                alwaysExcluded: bookmarkedIds.union(trashedIds).union(queuedPhotoIds)
            )

        case .smart(let category):
            assetsToProcess = await fetchSmartAssets(
                category: category,
                limit: candidateLimit,
                excludedIds: excludedIds
            )

        case .person(let id, let name):
            assetsToProcess = fetchPersonAssets(
                personId: id,
                personName: name,
                limit: candidateLimit,
                excludedIds: excludedIds
            )
        }

        // A newer load replaced this one — don't overwrite its results
        guard !Task.isCancelled else { return }

        if assetsToProcess.isEmpty {
            if !appendToExisting {
                state = .loaded([])
            }
            return
        }

        await processAndLoadPhotos(
            assetsToProcess,
            sortOption: settings.sortOption,
            append: appendToExisting
        )
    }

    private var queuedPhotoIds: Set<String> {
        guard case .loaded(let photos) = state else { return [] }
        return Set(photos.map(\.id))
    }

    // MARK: - Library Asset Fetching

    /// - Parameter alwaysExcluded: photos that must never reappear, even after
    ///   the session history is cleared (bookmarked, trashed, already queued).
    private func fetchLibraryAssets(
        category: PhotoCategory,
        limit: Int,
        excludedIds: Set<String>,
        alwaysExcluded: Set<String>
    ) async -> [PHAsset] {
        let result = await fetchLibraryCandidates(category: category, limit: limit, excluding: excludedIds)
        guard result.isEmpty, !reviewedPhotoIds.isEmpty else { return result }

        // Everything left has been seen this session — cycle back to skipped photos
        AppLogger.general.info("Clearing review history — all photos in category were seen")
        reviewedPhotoIds.removeAll()
        return await fetchLibraryCandidates(category: category, limit: limit, excluding: alwaysExcluded)
    }

    private func fetchLibraryCandidates(
        category: PhotoCategory,
        limit: Int,
        excluding excluded: Set<String>
    ) async -> [PHAsset] {
        let sortOption = settings.sortOption
        let dateRange = yearFilter?.yearRange

        if sortOption == .random {
            if category == .all && dateRange == nil {
                // Spreads picks across the whole timeline
                return await photoService.fetchRandomAssets(count: limit, excluding: excluded)
            }
            return await Task.detached {
                PhotoCategoryService.shared.fetchRandomAssets(
                    category: category, count: limit, excluding: excluded, dateRange: dateRange
                )
            }.value
        }

        let sortDescriptors = sortOption.sortDescriptors
        return await Task.detached {
            PhotoCategoryService.shared.fetchAssets(
                category: category,
                limit: limit,
                sortDescriptors: sortDescriptors,
                excluding: excluded,
                dateRange: dateRange
            )
        }.value
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

    private func processAndLoadPhotos(
        _ assets: [PHAsset],
        sortOption: PhotoSortOption,
        append: Bool = false
    ) async {
        let targetCount = batchSize
        var loaded = [(index: Int, photo: Photo, asset: PHAsset)]()
        var iterator = assets.enumerated().makeIterator()

        // Bounded concurrency — process candidates until we have enough
        // successfully-loaded photos or run out of assets.
        await withTaskGroup(of: (Int, Photo, PHAsset)?.self) { group in
            func enqueueNext() {
                guard let (index, asset) = iterator.next() else { return }
                group.addTask { [weak self] in
                    guard let self, let photo = await self.processAsset(asset) else { return nil }
                    return (index, photo, asset)
                }
            }

            for _ in 0..<min(maxConcurrentImageLoads, assets.count) {
                enqueueNext()
            }

            for await result in group {
                if let result {
                    loaded.append(result)
                }
                guard loaded.count < targetCount else {
                    group.cancelAll()
                    break
                }
                enqueueNext()
            }
        }

        guard !Task.isCancelled else { return }

        // Loads finish out of order — restore the fetch (sort) order
        loaded.sort { $0.index < $1.index }

        for item in loaded {
            reviewedPhotoIds.insert(item.photo.id)
            assetLookup[item.photo.id] = item.asset
        }

        // Cap reviewedPhotoIds to prevent unbounded Set growth over long sessions
        if reviewedPhotoIds.count > 2_000 {
            reviewedPhotoIds = Set(reviewedPhotoIds.dropFirst(reviewedPhotoIds.count - 2_000))
        }

        let newPhotos = sortOption == .random ? loaded.map(\.photo).shuffled() : loaded.map(\.photo)

        let allPhotos: [Photo]
        if append, case .loaded(let existing) = state {
            let existingIds = Set(existing.map(\.id))
            allPhotos = existing + newPhotos.filter { !existingIds.contains($0.id) }
        } else {
            allPhotos = newPhotos
        }

        state = .loaded(allPhotos)
        // Trim assetLookup to only current photo IDs to prevent unbounded growth
        let currentIds = Set(allPhotos.map(\.id))
        assetLookup = assetLookup.filter { currentIds.contains($0.key) }

        scheduleTopPhotoUpgrade()
    }

    private func scheduleTopPhotoUpgrade() {
        upgradeTask?.cancel()
        upgradeTask = Task { await upgradeTopPhotos() }
    }

    /// Loads sharper images for the top two cards so a swipe reveals a crisp photo
    private func upgradeTopPhotos() async {
        guard case .loaded(let photos) = state else { return }

        for photo in photos.prefix(2) where !upgradedPhotoIds.contains(photo.id) {
            guard !Task.isCancelled, let asset = assetLookup[photo.id] else { continue }
            guard let hqImage = await photoService.loadImage(for: asset, size: topCardImageSize) else { continue }

            guard !Task.isCancelled,
                  case .loaded(var currentPhotos) = state,
                  let index = currentPhotos.firstIndex(where: { $0.id == photo.id }) else { continue }

            currentPhotos[index].image = hqImage
            upgradedPhotoIds.insert(photo.id)
            state = .loaded(currentPhotos)
        }
    }

    /// Returns the PHAsset for a given photo ID, if available in the current lookup
    func asset(for photoId: String) -> PHAsset? {
        assetLookup[photoId]
    }

    /// Loads a single photo using a local-first strategy:
    /// 1. Try device-cached image (instant, no iCloud download)
    /// 2. Fall back to network load with timeout
    /// Returns nil if both fail (iCloud-only photo on slow connection — skip it)
    private func processAsset(_ asset: PHAsset) async -> Photo? {
        // Fast path: try locally-cached image first (no network)
        var image = await photoService.loadLocalImage(for: asset, size: cardImageSize)

        // Slow path: allow iCloud download with timeout
        if image == nil {
            image = await photoService.loadImage(for: asset, size: cardImageSize)
        }

        guard let image else { return nil }

        let fileSize = await asset.fetchFileSize()

        let analysisResult = analysisService?.cacheManager.getCachedResult(
            assetIdentifier: asset.localIdentifier
        )

        return Photo(
            id: asset.localIdentifier,
            image: image,
            creationDate: asset.creationDate,
            fileSize: fileSize,
            analysisResult: analysisResult,
            duration: asset.mediaType == .video ? asset.duration : nil
        )
    }

    // MARK: - Review Actions

    /// Bookmarks (right) or moves to trash (left). Confirmation, if enabled,
    /// is handled by the view before calling this.
    func handleSwipe(_ direction: SwipeDirection, for photo: Photo) {
        let action: ReviewAction = direction == .right ? .bookmark : .delete

        switch action {
        case .bookmark:
            bookmarkManager.setBookmarked(true, assetIdentifier: photo.id)
            haptic.impact(.light)
        case .delete:
            trashManager.addToTrash(assetIdentifier: photo.id)
            sessionStorageSaved += photo.fileSize
            haptic.impact(.medium)
        }

        analytics.record(action, assetIdentifier: photo.id)
        sessionReviewCount += 1
        pushUndo(ReviewedPhoto(photo: photo, asset: assetLookup[photo.id], action: action))
        removePhoto(photo)

        if action == .delete, storageTarget > 0, sessionStorageSaved >= storageTarget, !sessionTargetReached {
            sessionTargetReached = true
        }

        autoLoadMoreIfNeeded()
    }

    /// Sends the photo to the bottom of the stack
    func skipPhoto(_ photo: Photo) {
        guard case .loaded(var photos) = state,
              photos.count > 1,
              let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }

        let skippedPhoto = photos.remove(at: index)
        photos.append(skippedPhoto)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state = .loaded(photos)
        }
        haptic.impact(.light)
        scheduleTopPhotoUpgrade()
    }

    /// Reverses the most recent bookmark or delete and puts the photo back on top
    func undoLastAction() {
        guard let last = undoStack.popLast() else { return }
        canUndo = !undoStack.isEmpty

        switch last.action {
        case .bookmark:
            bookmarkManager.setBookmarked(false, assetIdentifier: last.photo.id)
        case .delete:
            trashManager.restoreFromTrash(assetIdentifier: last.photo.id)
            sessionStorageSaved = max(0, sessionStorageSaved - last.photo.fileSize)
        }
        analytics.revert(last.action, assetIdentifier: last.photo.id)
        sessionReviewCount = max(0, sessionReviewCount - 1)

        if let asset = last.asset {
            assetLookup[last.photo.id] = asset
        }

        var photos: [Photo]
        if case .loaded(let current) = state {
            photos = current.filter { $0.id != last.photo.id }
        } else {
            photos = []
        }
        photos.insert(last.photo, at: 0)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            state = .loaded(photos)
        }
        haptic.impact(.light)
    }

    // MARK: - Trash All for Person

    func trashAllPhotos(of person: PersonAlbum) {
        guard let peopleService else { return }
        Task {
            let assets = peopleService.fetchAllAssets(for: person)
            guard !assets.isEmpty else { return }
            trashManager.addToTrash(assetIdentifiers: assets.map(\.localIdentifier))
            analytics.recordBulkDeletion(count: assets.count)
            haptic.impact(.medium)
        }
    }

    // MARK: - Private Helpers

    private func pushUndo(_ item: ReviewedPhoto) {
        undoStack.append(item)
        if undoStack.count > maxUndoDepth {
            undoStack.removeFirst(undoStack.count - maxUndoDepth)
        }
        canUndo = true
    }

    private func clearUndo() {
        undoStack.removeAll()
        canUndo = false
    }

    private func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
        upgradeTask?.cancel()
        upgradeTask = nil
    }

    private func removePhoto(_ photo: Photo) {
        assetLookup.removeValue(forKey: photo.id)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state.removePhoto(photo)
        }
        scheduleTopPhotoUpgrade()
    }

    /// Triggers an append-load when the photo queue is running low
    private func autoLoadMoreIfNeeded() {
        guard case .loaded(let photos) = state,
              photos.count <= autoLoadThreshold,
              !sessionTargetReached else { return }
        loadMorePhotos()
    }
}

// MARK: - ViewState

extension ReviewViewModel {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded([Photo])
        case noAccess(PHAuthorizationStatus)
        case error(Error)

        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading):
                return true
            case (.loaded(let lhsPhotos), .loaded(let rhsPhotos)):
                return lhsPhotos.map(\.id) == rhsPhotos.map(\.id)
            case (.noAccess(let lhsStatus), .noAccess(let rhsStatus)):
                return lhsStatus == rhsStatus
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
