//
//  MascotMessage.swift
//  SnapSort
//
//  Empty / status states fronted by Snappy
//

import SwiftUI

struct MascotMessage<Actions: View>: View {
    var mood: Snappy.Mood = .happy
    let title: String
    let message: String
    private let actions: Actions

    init(
        mood: Snappy.Mood = .happy,
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.mood = mood
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Snappy(mood: mood, size: 110)
                .padding(.bottom, AppSpacing.xs)

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            actions
                .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension MascotMessage where Actions == EmptyView {
    init(mood: Snappy.Mood = .happy, title: String, message: String) {
        self.init(mood: mood, title: title, message: message) { EmptyView() }
    }
}

/// Compact chunky button for use inside messages
struct SmallChunkyButton: View {
    let title: String
    var systemImage: String?
    var fill: Color = AppColors.brand
    var foreground: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.chunky(fill, foreground: foreground))
    }
}

// MARK: - Chunky Progress

/// Thick, rounded progress bar
struct ChunkyProgressStyle: ProgressViewStyle {
    var tint: Color = AppColors.brand
    var height: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        let fraction = min(max(configuration.fractionCompleted ?? 0, 0), 1)
        Capsule()
            .fill(AppColors.placeholder)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint)
                        .frame(width: fraction > 0 ? max(height, proxy.size.width * fraction) : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: fraction)
                }
            }
            .clipShape(Capsule())
    }
}

extension ProgressViewStyle where Self == ChunkyProgressStyle {
    static var chunky: ChunkyProgressStyle { ChunkyProgressStyle() }
}
