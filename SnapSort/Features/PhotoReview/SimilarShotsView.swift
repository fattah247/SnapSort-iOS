//
//  SimilarShotsView.swift
//  SnapSort
//
//  Review sets of near-identical photos: keep the best, trash the rest.
//

import SwiftUI
import Photos

struct SimilarShotsView: View {
    @ObservedObject var viewModel: ReviewViewModel

    private var photoCount: Int {
        viewModel.similarGroups.reduce(0) { $0 + $1.assetIdentifiers.count }
    }

    var body: some View {
        Group {
            if viewModel.similarGroups.isEmpty {
                MascotMessage(
                    mood: viewModel.hasLoadedSmartCounts ? .sleepy : .curious,
                    title: viewModel.hasLoadedSmartCounts ? "No look-alikes here" : "Looking for look-alikes…",
                    message: "When you take a few shots of the same moment, they'll gather here so you can keep the best one."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        header
                        ForEach(viewModel.similarGroups) { group in
                            SimilarGroupCard(group: group, viewModel: viewModel)
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.groupedBackground)
        .navigationTitle("Similar Shots")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refreshSmartCounts() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Snappy(mood: .happy, size: 52, animated: false)
            VStack(alignment: .leading, spacing: 4) {
                Text("^[\(viewModel.similarGroups.count) set](inflect: true) · ^[\(photoCount) photo](inflect: true)")
                    .font(.headline)
                Text("I picked the sharpest shot in each set. Tap photos to change what you keep.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Group Card

private struct SimilarGroupCard: View {
    let group: SimilarShotGroup
    @ObservedObject var viewModel: ReviewViewModel

    @State private var assets: [PHAsset] = []
    @State private var bestID: String?
    @State private var keepers: Set<String> = []
    @State private var previewAsset: PHAsset?

    private var trashCount: Int { group.assetIdentifiers.count - keepers.count }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(dateText)
                    .font(.headline)
                Spacer()
                Text("^[\(group.assetIdentifiers.count) photo](inflect: true)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                        thumbnail(asset, index: index)
                    }
                }
                .padding(.vertical, AppSpacing.xxs)
            }
            .scrollIndicators(.hidden)

            HStack {
                Button("Keep All") {
                    viewModel.resolveSimilarGroup(group, keeping: Set(group.assetIdentifiers))
                }
                .font(.headline)

                Spacer()

                Button {
                    viewModel.resolveSimilarGroup(group, keeping: keepers)
                } label: {
                    Label("Trash \(trashCount)", systemImage: "trash.fill")
                        .font(.headline)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs + 2)
                }
                .buttonStyle(.chunky(AppColors.delete))
                .disabled(trashCount == 0)
            }
        }
        .cardStyle()
        .task(id: group.id) { await load() }
        .sheet(item: $previewAsset) { asset in
            PhotoDetailView(asset: asset)
        }
    }

    private var dateText: String {
        guard let date = assets.first?.creationDate else { return "Similar shots" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func thumbnail(_ asset: PHAsset, index: Int) -> some View {
        let id = asset.localIdentifier
        let isKept = keepers.contains(id)
        let isBest = id == bestID

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                if isKept { keepers.remove(id) } else { keepers.insert(id) }
            }
        } label: {
            AssetGridCell(asset: asset)
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall + 4, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall + 4, style: .continuous)
                        .strokeBorder(isKept ? AppColors.brand : .clear, lineWidth: 3)
                }
                .saturation(isKept ? 1 : 0.3)
                .opacity(isKept ? 1 : 0.6)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: isKept ? "checkmark.circle.fill" : "trash.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, isKept ? AppColors.brand : AppColors.delete)
                        .padding(6)
                }
                .overlay(alignment: .topLeading) {
                    if isBest {
                        Text("Best")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(AppColors.keepInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppColors.keep, in: Capsule())
                            .padding(6)
                    }
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                previewAsset = asset
            } label: {
                Label("View Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo \(index + 1) of \(assets.count)\(isBest ? ", best shot" : "")")
        .accessibilityValue(isKept ? "Keep" : "Trash")
        .accessibilityHint("Double-tap to switch between keep and trash")
        .accessibilityAddTraits(.isButton)
    }

    private func load() async {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: group.assetIdentifiers, options: nil)
        var byID: [String: PHAsset] = [:]
        result.enumerateObjects { asset, _, _ in byID[asset.localIdentifier] = asset }
        assets = group.assetIdentifiers.compactMap { byID[$0] }

        let best = await viewModel.suggestedKeeper(in: group)
        bestID = best
        keepers = best.map { [$0] } ?? []
    }
}
