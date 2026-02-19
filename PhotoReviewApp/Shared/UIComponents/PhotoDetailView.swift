//
//  PhotoDetailView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import SwiftUI
import Photos
import CoreData
import OSLog

struct PhotoDetailView: View {
    let asset: PHAsset
    @EnvironmentObject var photoService: PhotoLibraryService
    @State private var image: UIImage?
    @State private var showMetadata = false
    @Environment(\.dismiss) var dismiss

    // Zoom state
    @State private var zoomScale: CGFloat = 1.0
    @GestureState private var gestureScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    private var effectiveScale: CGFloat {
        zoomScale * gestureScale
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(effectiveScale)
                        .offset(CGSize(
                            width: offset.width + dragOffset.width,
                            height: offset.height + dragOffset.height
                        ))
                        .gesture(zoomGesture)
                        .gesture(panGesture)
                        .gesture(doubleTapGesture)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }

            // Top bar
            VStack {
                HStack {
                    closeButton
                    Spacer()
                    infoButton
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)

                Spacer()

                // Bottom bar
                shareButton
                    .padding(.bottom, AppSpacing.lg)
            }

            // Metadata overlay
            if showMetadata {
                metadataPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.appSpring, value: showMetadata)
        .task { await loadFullImage() }
    }

    // MARK: - Gestures

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .updating($gestureScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let newScale = zoomScale * value.magnification
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if newScale < 1.0 {
                        zoomScale = 1.0
                        offset = .zero
                    } else {
                        zoomScale = min(newScale, 5.0)
                    }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if zoomScale > 1.0 {
                    state = value.translation
                }
            }
            .onEnded { value in
                if zoomScale > 1.0 {
                    offset = CGSize(
                        width: offset.width + value.translation.width,
                        height: offset.height + value.translation.height
                    )
                }
            }
    }

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if zoomScale > 1.0 {
                        zoomScale = 1.0
                        offset = .zero
                    } else {
                        zoomScale = 2.0
                    }
                }
            }
    }

    // MARK: - UI Components

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private var infoButton: some View {
        Button {
            showMetadata.toggle()
        } label: {
            Image(systemName: showMetadata ? "info.circle.fill" : "info.circle")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let image {
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview("Photo", image: Image(uiImage: image))
            ) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Share")
                        .font(AppTypography.labelMedium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var metadataPanel: some View {
        VStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Taken: \(asset.creationDate?.formatted(date: .long, time: .shortened) ?? "Unknown")")
                Text("Size: \(asset.fileSize.formatted(.byteCount(style: .file)))")
                Text("Dimensions: \(asset.pixelWidth)x\(asset.pixelHeight)")
            }
            .font(AppTypography.caption)
            .foregroundColor(.white)
            .padding(AppSpacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
            .padding(.top, 60) // below top bar

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Image Loading

    private func loadFullImage() async {
        let screenScale = await MainActor.run { UIScreen.main.scale }
        let screenSize = await MainActor.run { UIScreen.main.bounds.size }
        let targetSize = CGSize(
            width: screenSize.width * screenScale,
            height: screenSize.height * screenScale
        )
        image = await photoService.loadImage(for: asset, size: targetSize)
    }
}
