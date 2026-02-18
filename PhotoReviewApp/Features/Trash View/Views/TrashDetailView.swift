//
//  TrashDetailView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 05/02/25.
//

import SwiftUI
import Photos

struct TrashDetailView: View {
    let asset: PHAsset
    @EnvironmentObject var trashManager: CoreDataTrashManager
    @EnvironmentObject var photoService: PhotoLibraryService
    @Environment(\.dismiss) var dismiss
    @State private var image: UIImage?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
            
            actionButtons
        }
        .task { await loadFullImage() }
        .background(.black)
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 20) {
            Button {
                trashManager.restoreFromTrash(assetIdentifier: asset.localIdentifier)
                dismiss()
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            
            Button(role: .destructive) {
                trashManager.emptyTrash()
                dismiss()
            } label: {
                Label("Delete Forever", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func loadFullImage() async {
        image = await photoService.loadImage(
            for: asset,
            size: PHImageManagerMaximumSize
        )
    }
}
