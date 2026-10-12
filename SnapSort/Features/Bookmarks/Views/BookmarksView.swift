//
//  BookmarksView.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import SwiftUI
import Photos

enum BookmarkSortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case photoDate = "Date Taken"
    case fileSize = "File Size"

    var descendingLabel: String {
        self == .fileSize ? "Largest First" : "Newest First"
    }

    var ascendingLabel: String {
        self == .fileSize ? "Smallest First" : "Oldest First"
    }
}

struct BookmarksView: View {
    @EnvironmentObject var bookmarkManager: CoreDataBookmarkManager
    @EnvironmentObject var appState: AppStateManager

    @AppStorage("bookmarkSortOption") private var sortOption: BookmarkSortOption = .dateAdded
    @AppStorage("bookmarkSortDescending") private var sortDescending = true
    @State private var selectedAsset: PHAsset?
    @State private var fileSizes: [String: Int64] = [:]
    @State private var isSelecting = false
    @State private var selection = Set<String>()

    private var sortedAssets: [PHAsset] {
        // The manager returns newest bookmark first
        let assets = bookmarkManager.bookmarkedAssets
        let ascending: [PHAsset]

        switch sortOption {
        case .dateAdded:
            ascending = assets.reversed()
        case .photoDate:
            ascending = assets.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        case .fileSize:
            ascending = assets.sorted { (fileSizes[$0.localIdentifier] ?? 0) < (fileSizes[$1.localIdentifier] ?? 0) }
        }

        return sortDescending ? ascending.reversed() : ascending
    }

    private var isEmpty: Bool { bookmarkManager.bookmarkedAssets.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.groupedBackground)
            .navigationTitle(isSelecting ? selectionTitle : "Bookmarks")
            .navigationBarTitleDisplayMode(isSelecting ? .inline : .large)
            .toolbar {
                if !isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSelecting ? "Done" : "Select") {
                            withAnimation { toggleSelecting() }
                        }
                        .fontWeight(isSelecting ? .semibold : .regular)
                    }
                    if !isSelecting {
                        ToolbarItem(placement: .topBarTrailing) {
                            sortMenu
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    selectionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $selectedAsset) { asset in
                PhotoDetailView(asset: asset) {
                    Spacer()
                    Button("Remove Bookmark", role: .destructive) {
                        bookmarkManager.setBookmarked(false, assetIdentifier: asset.localIdentifier)
                        selectedAsset = nil
                    }
                }
            }
            .task(id: sortOption) {
                if sortOption == .fileSize {
                    await loadFileSizes()
                }
            }
            .onChange(of: isEmpty) { _, empty in
                if empty { isSelecting = false }
            }
        }
    }

    private var selectionTitle: String {
        selection.isEmpty ? "Select Items" : "\(selection.count) Selected"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        MascotMessage(
            mood: .curious,
            title: "No bookmarks yet",
            message: "Swipe right on a photo you love and it'll land here."
        ) {
            SmallChunkyButton(title: "Start Sorting", systemImage: "rectangle.stack") {
                appState.activeTab = .review
            }
        }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOption) {
                ForEach(BookmarkSortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            Picker("Order", selection: $sortDescending) {
                Text(sortOption.descendingLabel).tag(true)
                Text(sortOption.ascendingLabel).tag(false)
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - Grid

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: PhotoGrid.columns, spacing: AppSpacing.gridSpacing) {
                ForEach(sortedAssets) { asset in
                    Button {
                        if isSelecting {
                            toggle(asset)
                        } else {
                            selectedAsset = asset
                        }
                    } label: {
                        AssetGridCell(
                            asset: asset,
                            isSelected: isSelecting ? selection.contains(asset.localIdentifier) : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if !isSelecting {
                            Button(role: .destructive) {
                                bookmarkManager.setBookmarked(false, assetIdentifier: asset.localIdentifier)
                            } label: {
                                Label("Remove Bookmark", systemImage: "bookmark.slash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.gridSpacing)

            Text("^[\(bookmarkManager.bookmarkedAssets.count) bookmark](inflect: true)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, AppSpacing.lg)
        }
        .animation(.default, value: sortOption)
        .animation(.default, value: sortDescending)
    }

    // MARK: - Selection

    private var selectionBar: some View {
        GridActionBar {
            Button(selection.count == bookmarkManager.bookmarkedAssets.count ? "Deselect All" : "Select All") {
                if selection.count == bookmarkManager.bookmarkedAssets.count {
                    selection.removeAll()
                } else {
                    selection = Set(bookmarkManager.bookmarkedAssets.map(\.localIdentifier))
                }
            }
            Spacer()
            Button(role: .destructive) {
                bookmarkManager.removeBookmarks(assetIdentifiers: selection)
                selection.removeAll()
                withAnimation { isSelecting = false }
            } label: {
                Text(selection.isEmpty ? "Remove" : "Remove \(selection.count)")
            }
            .disabled(selection.isEmpty)
        }
    }

    private func toggleSelecting() {
        isSelecting.toggle()
        selection.removeAll()
    }

    private func toggle(_ asset: PHAsset) {
        if !selection.insert(asset.localIdentifier).inserted {
            selection.remove(asset.localIdentifier)
        }
    }

    private func loadFileSizes() async {
        for asset in bookmarkManager.bookmarkedAssets where fileSizes[asset.localIdentifier] == nil {
            guard !Task.isCancelled else { return }
            fileSizes[asset.localIdentifier] = await asset.fetchFileSize()
        }
    }
}

extension PHAsset: @retroactive Identifiable {
    public var id: String {
        localIdentifier
    }
}
