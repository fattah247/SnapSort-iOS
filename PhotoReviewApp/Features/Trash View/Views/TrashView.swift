//
//  TrashView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import SwiftUI
import Photos
import CoreData
import OSLog

struct TrashView: View {
    @EnvironmentObject var trashManager: CoreDataTrashManager
    @EnvironmentObject var photoService: PhotoLibraryService
    @EnvironmentObject var haptic: HapticService

    @State private var confirmationShow = false
    @State private var showInfoBanner = !UserDefaults.standard.bool(forKey: "hasSeenTrashInfo")
    @AppStorage("hasSeenTrashInfo") private var hasSeenTrashInfo = false

    @State private var totalTrashSize: Int64 = 0
    @State private var trashSizeTask: Task<Void, Never>?

    private func calculateTrashSize() async {
        var total: Int64 = 0
        for asset in trashManager.trashedAssets {
            guard !Task.isCancelled else { return }
            total += await asset.fetchFileSize()
        }
        guard !Task.isCancelled else { return }
        totalTrashSize = total
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.groupedBackground.ignoresSafeArea()

                if trashManager.trashedAssets.isEmpty {
                    EmptyTrashView()
                } else {
                    VStack(spacing: 0) {
                        // Info banner
                        if showInfoBanner {
                            infoBanner
                        }

                        // Storage summary
                        storageSummary

                        // Grid
                        trashGrid
                    }
                }
            }
            .navigationTitle("Trash")
            .toolbar {
                if !trashManager.trashedAssets.isEmpty {
                    Button(role: .destructive) {
                        haptic.impact(.heavy)
                        confirmationShow = true
                    } label: {
                        Label("Empty Trash", systemImage: "trash")
                    }
                }
            }
            .confirmationDialog("Empty Trash", isPresented: $confirmationShow, titleVisibility: .visible) {
                Button("Delete All Permanently", role: .destructive) {
                    emptyTrash()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete \(trashManager.trashedAssets.count) photos. This action cannot be undone.")
            }
            .task {
                await calculateTrashSize()
            }
            .onChange(of: trashManager.trashedAssets.count) { _, _ in
                trashSizeTask?.cancel()
                trashSizeTask = Task {
                    await calculateTrashSize()
                }
            }
        }
    }

    // MARK: - Info Banner
    private var infoBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("About Trash")
                    .font(AppTypography.labelMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("Photos are kept in Recently Deleted for 30 days. Restore via iOS Photos app.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Button {
                withAnimation(.appSpring) {
                    showInfoBanner = false
                    hasSeenTrashInfo = true
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.xs)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Storage Summary
    private var storageSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(trashManager.trashedAssets.count) items")
                    .font(AppTypography.labelMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("\(totalTrashSize.formatted(.byteCount(style: .file))) can be freed")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Trash Grid
    private var trashGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: AppSpacing.xs)],
                spacing: AppSpacing.xs
            ) {
                ForEach(trashManager.trashedAssets) { asset in
                    TrashItemView(asset: asset)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .offset(y: 100).combined(with: .opacity)
                        ))
                }
            }
            .padding(AppSpacing.md)
            .animation(.appSpring, value: trashManager.trashedAssets.count)
        }
    }

    private func emptyTrash() {
        withAnimation(.spring()) {
            trashManager.emptyTrash()
            haptic.notify(.warning)
        }
    }
}

// MARK: - Trash Item View
struct TrashItemView: View {
    let asset: PHAsset
    @EnvironmentObject var trashManager: CoreDataTrashManager
    @EnvironmentObject var photoService: PhotoLibraryService
    @EnvironmentObject var haptic: HapticService
    @State private var image: UIImage?

    private var daysRemaining: Int {
        guard let deletionDate = asset.creationDate else { return 30 }
        let calendar = Calendar.current
        let daysSinceDeletion = calendar.dateComponents([.day], from: deletionDate, to: Date()).day ?? 0
        return max(0, 30 - daysSinceDeletion)
    }

    private var daysColor: Color {
        if daysRemaining > 20 {
            return AppColors.success
        } else if daysRemaining > 10 {
            return AppColors.warning
        } else {
            return AppColors.danger
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image
            ZStack(alignment: .bottomLeading) {
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

                // Days remaining badge
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .semibold))
                    Text("\(daysRemaining)d")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(daysColor.opacity(0.9))
                .clipShape(Capsule())
                .padding(AppSpacing.xxs)
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

            // Restore button
            Button {
                haptic.impact(.medium)
                withAnimation(.appSpring) {
                    trashManager.restoreFromTrash(assetIdentifier: asset.localIdentifier)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 32, height: 32)

                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(AppSpacing.xxs)
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        image = await photoService.loadImage(
            for: asset,
            size: CGSize(width: 220, height: 220)
        )
    }
}
