//
//  PhotoCardView.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import SwiftUI

/// A single photo in the review stack, framed like a polaroid. Purely
/// presentational — the deck owns the drag gesture and passes in how far
/// the card has been swiped.
struct PhotoCardView: View {
    let photo: Photo
    /// -1 (fully toward trash) … 1 (fully toward bookmark); 0 at rest
    var swipeProgress: CGFloat = 0

    private let framePadding: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            photoArea
                .padding([.top, .horizontal], framePadding)
            caption
        }
        .background(
            AppColors.cardBackground,
            in: RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous)
        )
        .overlay(alignment: .topLeading) {
            sticker(title: "Bookmark", systemImage: "bookmark.fill", fill: AppColors.keep, ink: AppColors.keepInk, angle: -10)
                .padding(26)
                .opacity(Double(max(0, swipeProgress)))
                .scaleEffect(0.8 + 0.2 * max(0, swipeProgress), anchor: .topLeading)
        }
        .overlay(alignment: .topTrailing) {
            sticker(title: "Trash", systemImage: "trash.fill", fill: AppColors.delete, ink: .white, angle: 10)
                .padding(26)
                .opacity(Double(max(0, -swipeProgress)))
                .scaleEffect(0.8 + 0.2 * max(0, -swipeProgress), anchor: .topTrailing)
        }
        .shadow(color: .black.opacity(0.1), radius: 14, y: 6)
    }

    // MARK: - Photo

    private var photoArea: some View {
        AppColors.placeholder
            .overlay {
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: photo.isVideo ? "video" : "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                // Color wash hinting at the decision
                (swipeProgress > 0 ? AppColors.keep : AppColors.delete)
                    .opacity(Double(abs(swipeProgress)) * 0.3)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                if let duration = photo.durationText {
                    Label(duration, systemImage: "play.fill")
                        .font(.footnote.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall + 4, style: .continuous))
    }

    // MARK: - Caption

    private var caption: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(photo.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "Some day")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(photo.fileSize.formatted(.byteCount(style: .file)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            HStack(spacing: AppSpacing.xxs) {
                ForEach(tags) { category in
                    TagChip(category: category)
                }
            }
        }
        .lineLimit(1)
        .padding(.horizontal, AppSpacing.md + 2)
        .padding(.vertical, AppSpacing.sm)
    }

    /// The two most useful smart tags, cleanup reasons first
    private var tags: [SmartCategory] {
        photo.smartCategories
            .filter { $0 != .longVideos }
            .sorted { lhs, rhs in
                if lhs.section != rhs.section { return lhs.section == .cleanUp }
                return lhs.displayName < rhs.displayName
            }
            .prefix(2)
            .map { $0 }
    }

    // MARK: - Stickers

    private func sticker(title: String, systemImage: String, fill: Color, ink: Color, angle: Double) -> some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.heavy))
            .foregroundStyle(ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white, lineWidth: 3)
            }
            .rotationEffect(.degrees(angle))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            .accessibilityHidden(true)
    }
}

/// Small rounded label for a smart category, e.g. "Blurry"
struct TagChip: View {
    let category: SmartCategory

    var body: some View {
        Label {
            Text(category.displayName)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: category.icon)
                .foregroundStyle(category.color)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(category.color.opacity(0.14), in: Capsule())
    }
}
