//
//  SmartGroupsView.swift
//  SnapSort
//
//  Groups of photos found by on-device analysis, plus People albums.
//

import SwiftUI
import Combine

struct SmartGroupsView: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        List {
            if let analysisService = viewModel.analysisService {
                AnalysisProgressView(analysisService: analysisService)
            }

            if !viewModel.peopleAlbums.isEmpty {
                Section("Your People") {
                    PeoplePickerView(
                        albums: viewModel.peopleAlbums,
                        onTrashAll: { person in
                            viewModel.trashAllPhotos(of: person)
                        }
                    )
                    .listRowInsets(EdgeInsets())
                }
                .listRowBackground(AppColors.cardBackground)
            }

            ForEach(SmartCategory.Section.allCases, id: \.self) { section in
                Section {
                    ForEach(SmartCategory.allCases.filter { $0.section == section }) { category in
                        row(for: category)
                    }
                } header: {
                    Text(section.rawValue)
                } footer: {
                    if section == .browse {
                        Text("Photos are analyzed on this device. Nothing is uploaded.")
                    }
                }
                .listRowBackground(AppColors.cardBackground)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.groupedBackground)
        .refreshable {
            viewModel.loadSmartData()
        }
        .onAppear {
            viewModel.refreshSmartCounts()
        }
        .onReceive(scanFinished) { _ in
            viewModel.refreshSmartCounts()
        }
        .onReceive(batchFinished) { _ in
            // Let groups fill in while a long scan is still running
            viewModel.refreshSmartCounts()
        }
    }

    private var scanFinished: AnyPublisher<Date?, Never> {
        viewModel.analysisService?.$lastScanCompletedAt.dropFirst().eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
    }

    private var batchFinished: AnyPublisher<Int, Never> {
        let every = Constants.Analysis.backgroundBatchSize * 5
        return viewModel.analysisService?.$analysisProgress
            .map(\.analyzedPhotos)
            .removeDuplicates()
            .filter { $0 > 0 && $0 % every == 0 }
            .eraseToAnyPublisher()
            ?? Empty().eraseToAnyPublisher()
    }

    @ViewBuilder
    private func row(for category: SmartCategory) -> some View {
        let count = viewModel.smartCategoryCounts[category] ?? 0
        let isScanning = viewModel.analysisService?.analysisProgress.isScanning == true

        NavigationLink(value: CategorySelection.smart(category)) {
            SmartGroupRow(
                category: category,
                count: count,
                isPending: count == 0 && (isScanning || !viewModel.hasLoadedSmartCounts)
            )
        }
        // Similar shots open a list even when empty, so the explanation is reachable
        .disabled(count == 0 && category != .duplicates)
    }
}

// MARK: - Smart Group Row

private struct SmartGroupRow: View {
    let category: SmartCategory
    let count: Int
    let isPending: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: category.icon)
                .iconTile(category.color, size: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(count == 0 && !isPending ? .secondary : .primary)
                Text(category.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppSpacing.xs)

            if isPending {
                ProgressView()
            } else {
                Text(count, format: .number)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(count > 0 ? .primary : .tertiary)
                    .padding(.horizontal, AppSpacing.xs + 2)
                    .padding(.vertical, 3)
                    .background(count > 0 ? AppColors.placeholder : .clear, in: Capsule())
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isPending ? "Still looking" : "\(count) photos")
    }
}
