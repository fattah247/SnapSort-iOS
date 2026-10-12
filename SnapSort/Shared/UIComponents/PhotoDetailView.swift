//
//  PhotoDetailView.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import SwiftUI
import Photos
import AVKit

/// Full-screen photo viewer with pinch-to-zoom, info, and share.
/// Pass `bottomBar` to add context actions (e.g. Restore / Delete in Trash).
struct PhotoDetailView<BottomBar: View>: View {
    let asset: PHAsset
    /// Shown immediately while the full-size image loads
    var placeholder: UIImage?
    private let bottomBar: BottomBar
    private let hasBottomBar: Bool

    @EnvironmentObject var photoService: PhotoLibraryService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var fileSize: Int64?
    @State private var showInfo = false

    init(asset: PHAsset, placeholder: UIImage? = nil, @ViewBuilder bottomBar: () -> BottomBar) {
        self.asset = asset
        self.placeholder = placeholder
        self.bottomBar = bottomBar()
        self.hasBottomBar = true
    }

    var body: some View {
        NavigationStack {
            Group {
                if asset.mediaType == .video {
                    AssetVideoPlayer(asset: asset)
                } else if let displayImage = image ?? placeholder {
                    ZoomableImageView(image: displayImage)
                        .ignoresSafeArea()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .principal) {
                    titleView
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    infoButton
                    shareButton
                }
                if hasBottomBar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        bottomBar
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadFullImage() }
    }

    // MARK: - Toolbar

    private var titleView: some View {
        VStack(spacing: 0) {
            if let date = asset.creationDate {
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.headline)
                Text(date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Photo")
                    .font(.headline)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var infoButton: some View {
        Button {
            showInfo = true
        } label: {
            Label("Info", systemImage: "info.circle")
        }
        .popover(isPresented: $showInfo) {
            infoContent
                .presentationCompactAdaptation(.popover)
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let image, asset.mediaType == .image {
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview("Photo", image: Image(uiImage: image))
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var infoContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let date = asset.creationDate {
                LabeledContent("Taken", value: date.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent("Dimensions", value: "\(asset.pixelWidth) × \(asset.pixelHeight)")
            if asset.mediaType == .video {
                LabeledContent("Length", value: Duration.seconds(asset.duration).formatted(.time(pattern: asset.duration >= 3600 ? .hourMinuteSecond : .minuteSecond)))
            }
            LabeledContent("Size") {
                if let fileSize {
                    Text(fileSize.formatted(.byteCount(style: .file)))
                } else {
                    ProgressView()
                }
            }
        }
        .font(.subheadline)
        .padding(AppSpacing.md)
        .frame(minWidth: 260)
        .task {
            fileSize = await asset.fetchFileSize()
        }
    }

    // MARK: - Image Loading

    private func loadFullImage() async {
        guard asset.mediaType == .image else { return }
        let screenSize = UIScreen.main.bounds.size
        let targetSize = CGSize(
            width: screenSize.width * displayScale,
            height: screenSize.height * displayScale
        )
        image = await photoService.loadImage(for: asset, size: targetSize)
    }
}

extension PhotoDetailView where BottomBar == EmptyView {
    init(asset: PHAsset, placeholder: UIImage? = nil) {
        self.asset = asset
        self.placeholder = placeholder
        self.bottomBar = EmptyView()
        self.hasBottomBar = false
    }
}

// MARK: - Video

/// Plays a library video, downloading from iCloud if needed
private struct AssetVideoPlayer: View {
    let asset: PHAsset
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            let item = await withCheckedContinuation { continuation in
                PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
                    continuation.resume(returning: item)
                }
            }
            guard let item else { return }
            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer
            newPlayer.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
