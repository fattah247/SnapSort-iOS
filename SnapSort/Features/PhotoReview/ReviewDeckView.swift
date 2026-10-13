//
//  ReviewDeckView.swift
//  SnapSort
//
//  The swipeable card stack plus its button alternatives. Used for both the
//  library deck and smart-group / person decks.
//

import SwiftUI
import Photos

struct ReviewDeckView<Leading: View>: View {
    @ObservedObject private var viewModel: ReviewViewModel
    private let leading: Leading

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics

    @State private var dragOffset: CGSize = .zero
    @State private var draggingPhotoID: String?
    @State private var isCommitting = false
    @State private var isDragging = false
    @State private var swipeZone = SwipeZoneTracker()
    @State private var deckWidth: CGFloat = 360
    @State private var pendingDelete: Photo?
    @State private var detailItem: DetailItem?

    private struct DetailItem: Identifiable {
        let asset: PHAsset
        let placeholder: UIImage?
        var id: String { asset.localIdentifier }
    }

    init(viewModel: ReviewViewModel, @ViewBuilder leading: () -> Leading) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.leading = leading()
    }

    private var swipeThreshold: CGFloat { deckWidth * 0.3 }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .noAccess(let status):
                PhotoAccessView(status: status) {
                    Task { await viewModel.requestPhotoAccess() }
                }
            case .idle, .loading:
                sessionHeader
                loadingView
            case .error(let error):
                sessionHeader
                MascotMessage(mood: .sleepy, title: "Couldn't load photos", message: error.localizedDescription) {
                    SmallChunkyButton(title: "Try Again", systemImage: "arrow.clockwise") { viewModel.reload() }
                }
            case .loaded(let photos) where photos.isEmpty:
                sessionHeader
                if viewModel.isLoadingMore {
                    loadingView
                } else {
                    caughtUpView
                }
            case .loaded(let photos):
                sessionHeader
                deck(photos)
            }
        }
        .onAppear { haptics?.prepare() }
        .alert(
            "Move to Trash?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { photo in
            Button("Move to Trash", role: .destructive) {
                commit(.left, photo: photo)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("You can restore it from the Trash tab until you delete it.")
        }
        .sheet(item: $detailItem) { item in
            PhotoDetailView(asset: item.asset, placeholder: item.placeholder)
        }
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                leading
                Spacer(minLength: AppSpacing.sm)
                Label {
                    Text("\(viewModel.sessionStorageSaved.storageText) of \(viewModel.storageTarget.storageText)")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.tint)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Marked for deletion this session")
                .accessibilityValue("\(viewModel.sessionStorageSaved.storageText) of \(viewModel.storageTarget.storageText)")
            }
            ProgressView(value: viewModel.storageProgress)
                .progressViewStyle(.chunky)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.xs)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            Snappy(mood: .curious, size: 84)
            Text("Fetching your photos…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var caughtUpView: some View {
        MascotMessage(
            mood: .cheer,
            title: "All tidy!",
            message: "You've been through everything in \(viewModel.selectedCategory.displayName). Bookmarked and trashed items won't show up again."
        ) {
            // Skipped photos already cycle back on their own, so reloading the
            // same deck would just land here again — offer somewhere new instead
            switch viewModel.selectedCategory {
            case .library(.all):
                SmallChunkyButton(title: "Check Again", systemImage: "arrow.clockwise") {
                    viewModel.startOver()
                }
            case .library:
                SmallChunkyButton(title: "Review All Photos", systemImage: "photo.on.rectangle") {
                    viewModel.selectLibraryCategory(.all)
                }
            case .smart, .person:
                SmallChunkyButton(title: "Back to Groups", systemImage: "chevron.backward") {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Deck

    private func deck(_ photos: [Photo]) -> some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                ForEach(Array(photos.prefix(3).enumerated()), id: \.element.id) { index, photo in
                    card(photo, depth: index)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            // A phone-sized card reads better than a poster on iPad
            .frame(maxWidth: 560, maxHeight: 900)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { deckWidth = $0 }

            actionBar(top: photos.first, canSkip: photos.count > 1)
        }
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.sm)
    }

    private func card(_ photo: Photo, depth: Int) -> some View {
        let isTop = depth == 0
        let offset = photo.id == draggingPhotoID ? dragOffset : .zero

        return PhotoCardView(photo: photo, swipeProgress: isTop ? progress(for: offset) : 0)
            // Cards underneath peek out slightly, tilted like a loose pile
            .scaleEffect(1 - CGFloat(depth) * 0.04)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(depth) * (depth.isMultiple(of: 2) ? -2 : 2)))
            .offset(y: CGFloat(depth) * 6)
            .offset(offset)
            .rotationEffect(.degrees(reduceMotion ? 0 : rotation(for: offset)), anchor: .bottom)
            .zIndex(Double(-depth))
            .allowsHitTesting(isTop && !isCommitting)
            .onTapGesture { openDetail(photo) }
            .gesture(dragGesture(for: photo))
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .opacity
            ))
            .accessibilityHidden(!isTop)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: photo))
            .accessibilityAddTraits(.isImage)
            .accessibilityHint("Swipe left to move to Trash, right to bookmark.")
            .accessibilityAction { openDetail(photo) }
            .accessibilityAction(named: "Move to Trash") { swipe(.left, photo: photo) }
            .accessibilityAction(named: "Bookmark") { swipe(.right, photo: photo) }
            .accessibilityAction(named: "Skip") { viewModel.skipPhoto(photo) }
    }

    private func progress(for offset: CGSize) -> CGFloat {
        guard swipeThreshold > 0 else { return 0 }
        return min(max(offset.width / swipeThreshold, -1), 1)
    }

    private func rotation(for offset: CGSize) -> Double {
        min(max(Double(offset.width) / 20, -12), 12)
    }

    // MARK: - Gestures

    private func dragGesture(for photo: Photo) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isCommitting else { return }
                if !isDragging {
                    isDragging = true
                    // Wake the hardware now so the threshold click lands on time
                    haptics?.prepare()
                }
                draggingPhotoID = photo.id
                dragOffset = value.translation
                // A detent click when the card crosses into a swipe zone, a softer one leaving it
                if let feedback = swipeZone.update(offset: value.translation.width, threshold: swipeThreshold) {
                    haptics?.play(feedback)
                }
            }
            .onEnded { value in
                isDragging = false
                swipeZone.reset()
                guard !isCommitting else { return }

                let width = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let isFlick = abs(predicted) > swipeThreshold * 2.5

                if abs(width) > swipeThreshold || isFlick {
                    let decidingWidth = abs(width) > swipeThreshold ? width : predicted
                    swipe(decidingWidth > 0 ? .right : .left, photo: photo)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - Actions

    private func swipe(_ direction: SwipeDirection, photo: Photo) {
        guard !isCommitting else { return }

        if direction == .left && viewModel.requiresDeleteConfirmation {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                dragOffset = .zero
            }
            pendingDelete = photo
            return
        }
        commit(direction, photo: photo)
    }

    /// Animates the card off-screen, then records the decision
    private func commit(_ direction: SwipeDirection, photo: Photo) {
        isCommitting = true
        // On the release frame, together with the card starting to fly off
        haptics?.play(direction == .right ? .bookmark : .trash)
        draggingPhotoID = photo.id
        let distance = deckWidth + 160

        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = CGSize(
                width: direction == .right ? distance : -distance,
                height: dragOffset.height + 30
            )
        } completion: {
            viewModel.handleSwipe(direction, for: photo)
            draggingPhotoID = nil
            dragOffset = .zero
            isCommitting = false
        }
    }

    private func openDetail(_ photo: Photo) {
        guard let asset = viewModel.asset(for: photo.id) else { return }
        detailItem = DetailItem(asset: asset, placeholder: photo.image)
    }

    private func accessibilityLabel(for photo: Photo) -> String {
        let kind = photo.isVideo ? "Video" : "Photo"
        let date = photo.creationDate?.formatted(date: .long, time: .omitted) ?? "unknown date"
        var label = "\(kind) from \(date), \(photo.fileSize.formatted(.byteCount(style: .file)))"
        if let duration = photo.durationText { label += ", \(duration) long" }
        return label
    }

    // MARK: - Action Bar

    private func actionBar(top: Photo?, canSkip: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xl) {
            DeckActionButton(
                title: "Trash",
                systemImage: "trash.fill",
                fill: AppColors.delete,
                ink: .white,
                shortcut: .leftArrow
            ) {
                if let top { swipe(.left, photo: top) }
            }
            DeckActionButton(
                title: "Skip",
                systemImage: "arrow.uturn.forward",
                fill: AppColors.cardBackground,
                ink: .secondary,
                diameter: 54,
                shortcut: .downArrow
            ) {
                if let top, !isCommitting { viewModel.skipPhoto(top) }
            }
            .disabled(!canSkip)
            DeckActionButton(
                title: "Bookmark",
                systemImage: "bookmark.fill",
                fill: AppColors.keep,
                ink: AppColors.keepInk,
                shortcut: .rightArrow
            ) {
                if let top { swipe(.right, photo: top) }
            }
        }
        // Taps during the fly-off are ignored by `swipe`, so don't dim here — it would flicker
        .disabled(top == nil)
    }
}

extension ReviewDeckView where Leading == EmptyView {
    init(viewModel: ReviewViewModel) {
        self.init(viewModel: viewModel) { EmptyView() }
    }
}

// MARK: - Deck Action Button

private struct DeckActionButton: View {
    let title: String
    let systemImage: String
    let fill: Color
    let ink: Color
    var diameter: CGFloat = 68
    let shortcut: KeyEquivalent
    let action: () -> Void

    @State private var taps = 0

    /// All buttons share this height so their captions line up
    private let rowHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Button {
                taps += 1
                action()
            } label: {
                Image(systemName: systemImage)
                    .font(.system(size: diameter * 0.36, weight: .bold))
                    .symbolEffect(.bounce, value: taps)
                    .frame(width: diameter, height: diameter)
            }
            // The decision itself plays a haptic, so no key-down tap on top
            .buttonStyle(ChunkyButtonStyle(fill: fill, foreground: ink, shape: .circle, pressFeedback: false))
            .keyboardShortcut(shortcut, modifiers: [])
            .accessibilityLabel(title)
            .frame(height: rowHeight)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Photo Access

struct PhotoAccessView: View {
    let status: PHAuthorizationStatus
    let onRequest: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        if status == .notDetermined {
            MascotMessage(
                mood: .curious,
                title: "Let's peek at your photos",
                message: "SnapSort needs access to your library to show photos for review. Your photos stay on this device."
            ) {
                SmallChunkyButton(title: "Continue", action: onRequest)
            }
        } else {
            MascotMessage(
                mood: .sleepy,
                title: "Photo access is off",
                message: "Turn on photo access for SnapSort in Settings to start sorting."
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    SmallChunkyButton(title: "Open Settings") { openURL(url) }
                }
            }
        }
    }
}
