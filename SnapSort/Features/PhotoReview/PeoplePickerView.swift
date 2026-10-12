//
//  PeoplePickerView.swift
//  SnapSort
//
//  Horizontal scroll of People albums with circular thumbnails
//

import SwiftUI
import Photos

struct PeoplePickerView: View {
    let albums: [PersonAlbum]
    let onTrashAll: (PersonAlbum) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                ForEach(albums) { person in
                    PersonBubble(person: person) {
                        onTrashAll(person)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Person Bubble

struct PersonBubble: View {
    let person: PersonAlbum
    let onTrashAll: () -> Void

    @EnvironmentObject var photoService: PhotoLibraryService
    @Environment(\.displayScale) private var displayScale
    @State private var thumbnail: UIImage?
    @State private var showTrashConfirmation = false

    private let diameter: CGFloat = 64

    var body: some View {
        NavigationLink(value: CategorySelection.person(id: person.id, name: person.name)) {
            VStack(spacing: AppSpacing.xxs) {
                AppColors.placeholder
                    .overlay {
                        if let thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())

                Text(person.name)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(person.assetCount, format: .number)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(person.name)
        .accessibilityValue("\(person.assetCount) photos")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button(role: .destructive) {
                showTrashConfirmation = true
            } label: {
                Label("Move All to Trash", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Move all \(person.assetCount) photos of \(person.name) to Trash?",
            isPresented: $showTrashConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                onTrashAll()
            }
        } message: {
            Text("Nothing is deleted until you empty the Trash.")
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let keyAsset = person.keyAsset else { return }
        let side = diameter * displayScale
        thumbnail = await photoService.loadImage(for: keyAsset, size: CGSize(width: side, height: side))
    }
}
