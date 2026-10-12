//
//  AssetGridCell.swift
//  SnapSort
//
//  Square photo thumbnail for Photos-style grids
//

import SwiftUI
import Photos

struct AssetGridCell: View {
    let asset: PHAsset
    /// nil outside of select mode
    var isSelected: Bool?

    @EnvironmentObject private var photoService: PhotoLibraryService
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    /// Roughly a third of a phone screen — enough for a 3-column grid
    private let pointSize: CGFloat = 140

    var body: some View {
        AppColors.placeholder
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                if asset.mediaType == .video {
                    Text(Duration.seconds(asset.duration).formatted(.time(pattern: .minuteSecond)))
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .padding(6)
                }
            }
            .overlay {
                if isSelected == true {
                    Color.white.opacity(0.25)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let isSelected {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, isSelected ? AppColors.brand : .black.opacity(0.2))
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(isSelected == true ? [.isImage, .isButton, .isSelected] : [.isImage, .isButton])
            .task(id: asset.localIdentifier) {
                let side = pointSize * displayScale
                image = await photoService.loadImage(for: asset, size: CGSize(width: side, height: side))
            }
    }

    private var accessibilityLabel: String {
        let kind = asset.mediaType == .video ? "Video" : "Photo"
        guard let date = asset.creationDate else { return kind }
        return "\(kind) from \(date.formatted(date: .long, time: .omitted))"
    }
}

/// Small gutters like the Photos app: three columns on iPhone, more on iPad
enum PhotoGrid {
    static let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 220), spacing: AppSpacing.gridSpacing)
    ]
}

/// Bottom action bar used by grids in select mode
struct GridActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            content
        }
        .font(.headline)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
