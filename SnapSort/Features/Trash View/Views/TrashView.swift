//
//  TrashView.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import SwiftUI
import Photos

struct TrashView: View {
    @EnvironmentObject var trashManager: CoreDataTrashManager
    @EnvironmentObject var analytics: CoreDataAnalyticsService

    @State private var totalTrashSize: Int64?
    @State private var selectedAsset: PHAsset?
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?
    @State private var showRestoreAllConfirmation = false
    @State private var deletedCount = 0
    @State private var isSelecting = false
    @State private var selection = Set<String>()

    private var assets: [PHAsset] { trashManager.trashedAssets }

    var body: some View {
        NavigationStack {
            Group {
                if assets.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.groupedBackground)
            .navigationTitle(isSelecting ? selectionTitle : "Trash")
            .navigationBarTitleDisplayMode(isSelecting ? .inline : .large)
            .toolbar {
                if !assets.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSelecting ? "Done" : "Select") {
                            withAnimation {
                                isSelecting.toggle()
                                selection.removeAll()
                            }
                        }
                        .fontWeight(isSelecting ? .semibold : .regular)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !assets.isEmpty {
                    actionBar
                }
            }
            .sheet(item: $selectedAsset) { asset in
                TrashDetailView(
                    asset: asset,
                    onRestore: { restore([asset]) },
                    onDelete: { await delete([asset]) }
                )
            }
            .confirmationDialog(
                "Restore ^[\(assets.count) photo](inflect: true)?",
                isPresented: $showRestoreAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Restore All") {
                    restore(assets)
                }
            } message: {
                Text("They'll go back into your review queue.")
            }
            .alert(
                "Couldn't Delete Photos",
                isPresented: Binding(
                    get: { deleteErrorMessage != nil },
                    set: { if !$0 { deleteErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage ?? "")
            }
            .sensoryFeedback(.success, trigger: deletedCount)
            .task(id: assets.count) {
                await calculateTrashSize()
            }
            .onChange(of: assets.isEmpty) { _, empty in
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
            mood: deletedCount > 0 ? .cheer : .happy,
            title: deletedCount > 0 ? "Squeaky clean!" : "Trash is empty",
            message: deletedCount > 0
                ? "Those photos are in Recently Deleted in the Photos app for 30 days, just in case."
                : "Photos you swipe left on wait here. Nothing is removed from your library until you delete them."
        )
    }

    // MARK: - Grid

    private var grid: some View {
        ScrollView {
            summaryCard
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

            LazyVGrid(columns: PhotoGrid.columns, spacing: AppSpacing.gridSpacing) {
                ForEach(assets) { asset in
                    Button {
                        if isSelecting {
                            if !selection.insert(asset.localIdentifier).inserted {
                                selection.remove(asset.localIdentifier)
                            }
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
                            Button {
                                restore([asset])
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            Button(role: .destructive) {
                                Task { await delete([asset]) }
                            } label: {
                                Label("Delete Now", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.gridSpacing)
            .padding(.bottom, AppSpacing.lg)
        }
    }

    private var summaryCard: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Image(systemName: "trash.fill")
                .iconTile(AppColors.delete, size: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("^[\(assets.count) photo](inflect: true) waiting")
                    .font(.headline)
                if let totalTrashSize {
                    Text(assets.count == 1
                         ? "Delete it to clear about \(totalTrashSize.storageText). It'll stay in Recently Deleted for 30 days."
                         : "Delete them to clear about \(totalTrashSize.storageText). They'll stay in Recently Deleted for 30 days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Action Bar

    @ViewBuilder
    private var actionBar: some View {
        if isSelecting {
            GridActionBar {
                Button(selection.isEmpty ? "Restore" : "Restore \(selection.count)") {
                    restore(assets.filter { selection.contains($0.localIdentifier) })
                    selection.removeAll()
                    withAnimation { isSelecting = false }
                }
                .disabled(selection.isEmpty)
                Spacer()
                Button(role: .destructive) {
                    let chosen = assets.filter { selection.contains($0.localIdentifier) }
                    Task {
                        if await delete(chosen) {
                            selection.removeAll()
                            withAnimation { isSelecting = false }
                        }
                    }
                } label: {
                    Text(selection.isEmpty ? "Delete" : "Delete \(selection.count)")
                }
                .disabled(selection.isEmpty || isDeleting)
            }
        } else {
            HStack(spacing: AppSpacing.sm) {
                Button {
                    showRestoreAllConfirmation = true
                } label: {
                    ChunkyLabel(title: "Restore All")
                }
                .buttonStyle(.chunky(AppColors.cardBackground, foreground: .primary))

                Button {
                    Task { await delete(assets) }
                } label: {
                    Group {
                        if isDeleting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                        } else {
                            ChunkyLabel(title: "Delete All", systemImage: "trash.fill")
                        }
                    }
                }
                .buttonStyle(.chunky(AppColors.delete))
            }
            .disabled(isDeleting)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)
            .background(AppColors.groupedBackground.opacity(0.94))
        }
    }

    // MARK: - Actions

    private func restore(_ assetsToRestore: [PHAsset]) {
        guard !assetsToRestore.isEmpty else { return }
        if assetsToRestore.count == assets.count {
            trashManager.restoreAll()
        } else {
            trashManager.restoreFromTrash(assetIdentifiers: assetsToRestore.map(\.localIdentifier))
        }

        analytics.revertDeletion(assetIdentifiers: assetsToRestore.map(\.localIdentifier))
    }

    /// Hands the photos to PhotoKit, which shows its own confirmation.
    /// Returns true if they were deleted.
    @discardableResult
    private func delete(_ assetsToDelete: [PHAsset]) async -> Bool {
        guard !assetsToDelete.isEmpty else { return false }
        isDeleting = true
        defer { isDeleting = false }

        // Sizes have to be read while the photos still exist
        var bytes: Int64 = 0
        for asset in assetsToDelete {
            bytes += await asset.fetchFileSize()
        }

        do {
            try await trashManager.deletePermanently(assetIdentifiers: assetsToDelete.map(\.localIdentifier))
            analytics.recordSpaceCleared(bytes)
            deletedCount += 1
            return true
        } catch let error as PHPhotosError where error.code == .userCancelled {
            // The user tapped "Don't Allow" — nothing to report
            return false
        } catch {
            deleteErrorMessage = error.localizedDescription
            return false
        }
    }

    private func calculateTrashSize() async {
        var total: Int64 = 0
        for asset in assets {
            guard !Task.isCancelled else { return }
            total += await asset.fetchFileSize()
        }
        guard !Task.isCancelled else { return }
        totalTrashSize = total
    }
}
