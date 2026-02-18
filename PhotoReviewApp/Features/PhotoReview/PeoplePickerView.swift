//
//  PeoplePickerView.swift
//  PhotoReviewApp
//
//  Horizontal scroll of People albums with circular thumbnails
//

import SwiftUI
import Photos

struct PeoplePickerView: View {
    let albums: [PersonAlbum]
    let onSelectPerson: (PersonAlbum) -> Void
    let onDeleteAll: (PersonAlbum) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.md) {
                ForEach(albums) { person in
                    PersonBubble(
                        person: person,
                        onTap: { onSelectPerson(person) },
                        onDeleteAll: { onDeleteAll(person) }
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
        }
    }
}

// MARK: - Person Bubble

struct PersonBubble: View {
    let person: PersonAlbum
    let onTap: () -> Void
    let onDeleteAll: () -> Void

    @EnvironmentObject var photoService: PhotoLibraryService
    @State private var thumbnail: UIImage?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.xs) {
                // Circular thumbnail
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: 64, height: 64)

                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(AppColors.primary.opacity(0.5))
                    }

                    // Count badge
                    Text("\(person.assetCount)")
                        .font(AppTypography.badge)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(AppColors.primary)
                        )
                        .offset(x: 20, y: -24)
                }

                // Name
                Text(person.name)
                    .font(AppTypography.labelSmall)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .frame(width: 70)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onTap) {
                Label("Review Photos", systemImage: "photo.stack")
            }
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete All Photos", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete all photos of \(person.name)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(person.assetCount) Photos", role: .destructive) {
                onDeleteAll()
            }
        } message: {
            Text("This will move all \(person.assetCount) photos of \(person.name) to the trash.")
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let keyAsset = person.keyAsset else { return }
        let size = CGSize(width: 128, height: 128) // 2x for retina
        thumbnail = await photoService.loadImage(for: keyAsset, size: size)
    }
}
