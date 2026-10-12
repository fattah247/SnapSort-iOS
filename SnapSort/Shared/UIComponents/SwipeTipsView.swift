//
//  SwipeTipsView.swift
//  SnapSort
//
//  First-run sheet explaining how reviewing works
//

import SwiftUI

struct SwipeTipsView: View {
    @Environment(\.dismiss) private var dismiss
    /// Measured so the sheet hugs its content at every text size
    @State private var contentHeight: CGFloat = 560

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.sm) {
                Snappy(mood: .happy, size: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick tips")
                        .font(.title2.bold())
                    Text("Sorting takes a second per photo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, AppSpacing.lg)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                tip(
                    systemImage: "arrow.left",
                    tint: AppColors.delete,
                    title: "Swipe left to trash",
                    detail: "Nothing leaves your library until you empty the Trash."
                )
                tip(
                    systemImage: "arrow.right",
                    tint: AppColors.keep,
                    title: "Swipe right to bookmark",
                    detail: "Find your favorites again in the Bookmarks tab."
                )
                tip(
                    systemImage: "arrow.uturn.backward",
                    tint: AppColors.brand,
                    title: "Oops? Undo",
                    detail: "The Undo button brings back the last photo."
                )
                tip(
                    systemImage: "square.grid.2x2",
                    tint: AppColors.storage,
                    title: "Try Smart",
                    detail: "Find blurry shots, look-alikes, and screenshots fast."
                )
            }

            Button {
                dismiss()
            } label: {
                ChunkyLabel(title: "Let's Go")
            }
            .buttonStyle(.chunky)
            .padding(.top, AppSpacing.xs)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .presentationDetents([.height(contentHeight), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColors.groupedBackground)
    }

    private func tip(systemImage: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .iconTile(tint, size: 36, foreground: tint == AppColors.keep ? AppColors.keepInk : .white)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tutorial State Manager
enum SwipeTutorialManager {
    private static let key = "hasSeenSwipeTutorial"

    static var shouldShowTutorial: Bool {
        !UserDefaults.standard.bool(forKey: key)
    }

    static func markAsSeen() {
        UserDefaults.standard.set(true, forKey: key)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SwipeTipsView()
        }
}
