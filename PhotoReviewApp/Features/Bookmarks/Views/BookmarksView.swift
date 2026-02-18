//
//  BookmarksView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import SwiftUI
import Photos
import CoreData
import OSLog

enum BookmarkSortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case photoDate = "Photo Date"
    case fileSize = "File Size"

    var icon: String {
        switch self {
        case .dateAdded: return "clock"
        case .photoDate: return "calendar"
        case .fileSize: return "doc"
        }
    }
}

struct BookmarksView: View {
    @EnvironmentObject var bookmarkManager: CoreDataBookmarkManager
    @EnvironmentObject var photoService: PhotoLibraryService
    @EnvironmentObject var haptic: HapticService
    @EnvironmentObject var appState: AppStateManager

    @State private var selectedPhoto: PHAsset?
    @State private var sortOption: BookmarkSortOption = .dateAdded
    @State private var sortAscending = false
    @State private var showSortMenu = false

    private var sortedAssets: [PHAsset] {
        let assets = bookmarkManager.bookmarkedAssets
        let sorted: [PHAsset]

        switch sortOption {
        case .dateAdded:
            sorted = assets // Already sorted by date added from Core Data
        case .photoDate:
            sorted = assets.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        case .fileSize:
            sorted = assets.sorted { $0.fileSize < $1.fileSize }
        }

        return sortAscending ? sorted : sorted.reversed()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.groupedBackground.ignoresSafeArea()

                if bookmarkManager.bookmarkedAssets.isEmpty {
                    EmptyBookmarksView(onStartReviewing: {
                        appState.activeTab = .review
                    })
                } else {
                    VStack(spacing: 0) {
                        // Sort toolbar
                        sortToolbar
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)

                        // Grid
                        bookmarkGrid
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .sheet(item: $selectedPhoto) { asset in
                PhotoDetailView(asset: asset)
            }
        }
    }

    // MARK: - Sort Toolbar
    private var sortToolbar: some View {
        HStack {
            // Count
            Text("\(bookmarkManager.bookmarkedAssets.count) photos")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            // Sort button
            Menu {
                ForEach(BookmarkSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        withAnimation(.appSpring) {
                            if sortOption == option {
                                sortAscending.toggle()
                            } else {
                                sortOption = option
                                sortAscending = false
                            }
                        }
                        haptic.impact(.light)
                    }) {
                        HStack {
                            Image(systemName: option.icon)
                            Text(option.rawValue)
                            if sortOption == option {
                                Spacer()
                                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: sortOption.icon)
                    Text(sortOption.rawValue)
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(AppTypography.labelSmall)
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Bookmark Grid
    private var bookmarkGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: AppSpacing.xs)],
                spacing: AppSpacing.xs
            ) {
                ForEach(sortedAssets) { asset in
                    BookmarkItemView(asset: asset)
                        .onTapGesture { selectedPhoto = asset }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(AppSpacing.md)
            .animation(.appSpring, value: sortOption)
            .animation(.appSpring, value: sortAscending)
        }
    }
}

// MARK: - Bookmark Item View
struct BookmarkItemView: View {
    let asset: PHAsset
    @EnvironmentObject var bookmarkManager: CoreDataBookmarkManager
    @EnvironmentObject var photoService: PhotoLibraryService
    @EnvironmentObject var haptic: HapticService
    @State private var image: UIImage?
    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        AppColors.secondaryBackground
                        ProgressView()
                            .tint(AppColors.textTertiary)
                    }
                }
            }
            .frame(width: 110, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

            // Bookmark button
            Button {
                haptic.impact(.medium)
                withAnimation(.appSpring) {
                    bookmarkManager.toggleBookmark(assetIdentifier: asset.localIdentifier)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 32, height: 32)

                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.bookmark)
                }
            }
            .padding(AppSpacing.xxs)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .task { await loadImage() }
    }

    private func loadImage() async {
        image = await photoService.loadImage(
            for: asset,
            size: CGSize(width: 220, height: 220)
        )
    }
}

extension PHAsset: @retroactive Identifiable {
    public var id: String {
        localIdentifier
    }
}
