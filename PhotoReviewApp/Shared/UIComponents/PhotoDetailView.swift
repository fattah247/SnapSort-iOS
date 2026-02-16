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
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .gesture(
                TapGesture(count: 2).onEnded {
                    showMetadata.toggle()
                }
            )
            
            metadataPanel
            closeButton
        }
        .task { await loadFullImage() }
        .background(Color.black)
        .ignoresSafeArea()
    }
    
    private var metadataPanel: some View {
        VStack(alignment: .leading) {
            if showMetadata {
                Group {
                    Text("Taken: \(asset.creationDate?.formatted(date: .long, time: .shortened) ?? "Unknown")")
                    Text("Size: \(asset.fileSize.formatted(.byteCount(style: .file)))")
                    Text("Dimensions: \(asset.pixelWidth)x\(asset.pixelHeight)")
                }
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .transition(.move(edge: .top))
            }
        }
        .padding(AppSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
        .padding(AppSpacing.md)
        .animation(.appSpring, value: showMetadata)
    }
    
    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.white)
                .padding()
        }
    }
    
    private func loadFullImage() async {
        // Use screen-scale-aware size instead of PHImageManagerMaximumSize
        // which would load the full raw image (~185MB for modern photos)
        let screenScale = await MainActor.run { UIScreen.main.scale }
        let screenSize = await MainActor.run { UIScreen.main.bounds.size }
        let targetSize = CGSize(
            width: screenSize.width * screenScale,
            height: screenSize.height * screenScale
        )
        image = await photoService.loadImage(for: asset, size: targetSize)
    }
}
