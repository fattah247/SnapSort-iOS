//
//  PhotoCardView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import SwiftUI
import Photos
import CoreData
import OSLog

struct PhotoCardView: View {
    let photo: Photo
    let viewModel: ReviewViewModel
    var onTap: (() -> Void)?
    var onSkip: (() -> Void)?

    @GestureState private var dragOffset = CGSize.zero
    @EnvironmentObject var haptic: HapticService

    @State private var overlayOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var hasTriggeredThresholdHaptic = false

    // Thresholds
    private let iconAppearThreshold: CGFloat = 30 // Show icons early (15% of typical screen)
    private let decisionThresholdRatio: CGFloat = 0.3

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: AppSpacing.sm) {
                // Card
                ZStack(alignment: .bottom) {
                    imageContent(for: geometry.size)
                        .overlay(swipeFeedbackOverlay(width: geometry.size.width))

                    metadataOverlay
                }
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusXLarge, style: .continuous)
                        .fill(AppColors.cardBackground)
                        .shadow(color: shadowColor, radius: 20, x: 0, y: 5)
                )
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width / 25)))
                .scaleEffect(1 - abs(dragOffset.width) / 1500)
                .onTapGesture { onTap?() }
                .gesture(dragGesture(geometry: geometry))
                .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: dragOffset)

                // Skip button
                if let onSkip = onSkip {
                    Button(action: onSkip) {
                        HStack(spacing: AppSpacing.xs) {
                            Text("Skip for later")
                                .font(AppTypography.labelMedium)
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.vertical, AppSpacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, AppSpacing.md)
    }

    private func imageContent(for size: CGSize) -> some View {
        ZStack {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusXLarge, style: .continuous))
            } else {
                Color.secondary.opacity(0.3)
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(width: size.width, height: size.height * 0.85)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusXLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusXLarge, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func swipeFeedbackOverlay(width: CGFloat) -> some View {
        let progress = abs(dragOffset.width) / (width * decisionThresholdRatio)
        let clampedProgress = min(progress, 1.0)

        return ZStack {
            // Gradient overlay based on swipe direction
            if dragOffset.width > 0 {
                LinearGradient(
                    colors: [AppColors.bookmark.opacity(0.0), AppColors.bookmark.opacity(0.4 * clampedProgress)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else if dragOffset.width < 0 {
                LinearGradient(
                    colors: [AppColors.delete.opacity(0.4 * clampedProgress), AppColors.delete.opacity(0.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }

            // Action icons
            swipeIndicators(progress: clampedProgress)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusXLarge, style: .continuous))
        .opacity(overlayOpacity)
    }

    private func swipeIndicators(progress: CGFloat) -> some View {
        HStack {
            // Delete indicator (left side)
            if dragOffset.width < -iconAppearThreshold {
                VStack(spacing: AppSpacing.xs) {
                    ZStack {
                        Circle()
                            .fill(AppColors.deleteGradient)
                            .frame(width: 60, height: 60)

                        Image(systemName: "trash.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(iconScale)

                    Text("Delete")
                        .font(AppTypography.labelSmall)
                        .foregroundColor(.white)
                        .opacity(progress > 0.5 ? 1 : 0)
                }
                .padding(.leading, AppSpacing.lg)
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Bookmark indicator (right side)
            if dragOffset.width > iconAppearThreshold {
                VStack(spacing: AppSpacing.xs) {
                    ZStack {
                        Circle()
                            .fill(AppColors.bookmarkGradient)
                            .frame(width: 60, height: 60)

                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(iconScale)

                    Text("Bookmark")
                        .font(AppTypography.labelSmall)
                        .foregroundColor(.white)
                        .opacity(progress > 0.5 ? 1 : 0)
                }
                .padding(.trailing, AppSpacing.lg)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        let decisionThreshold = geometry.size.width * decisionThresholdRatio

        return DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
                let absWidth = abs(value.translation.width)

                // Update overlay opacity — direct assignment, no withAnimation per frame
                overlayOpacity = min(absWidth / 100, 1.0)
                iconScale = min(0.5 + (absWidth / decisionThreshold) * 0.5, 1.0)

                // Haptic feedback at threshold
                if absWidth > decisionThreshold && !hasTriggeredThresholdHaptic {
                    haptic.impact(.medium)
                    hasTriggeredThresholdHaptic = true
                } else if absWidth < decisionThreshold && hasTriggeredThresholdHaptic {
                    hasTriggeredThresholdHaptic = false
                }
            }
            .onEnded { value in
                handleDragEnded(value.translation, threshold: decisionThreshold)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    overlayOpacity = 0
                    iconScale = 0.5
                }
                hasTriggeredThresholdHaptic = false
            }
    }

    private var metadataOverlay: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(photo.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown Date")
                        .font(AppTypography.caption)
                }

                HStack(spacing: 6) {
                    Image(systemName: "doc")
                        .font(.system(size: 11))
                    Text(photo.fileSize.formatted(.byteCount(style: .file)))
                        .font(AppTypography.caption)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous)
            )

            Spacer()

            // Smart category badges
            if !photo.smartCategories.isEmpty {
                categoryBadges
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.horizontal, .bottom], AppSpacing.md)
    }

    @ViewBuilder
    private var categoryBadges: some View {
        HStack(spacing: 4) {
            ForEach(Array(photo.smartCategories).prefix(3), id: \.self) { category in
                HStack(spacing: 3) {
                    Image(systemName: category.icon)
                        .font(.system(size: 9, weight: .semibold))
                    Text(category.rawValue)
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(category.color.opacity(0.85))
                )
            }
        }
    }

    private func handleDragEnded(_ translation: CGSize, threshold: CGFloat) {
        let direction: SwipeDirection = translation.width > 0 ? .right : .left

        if abs(translation.width) > threshold {
            viewModel.handleSwipe(direction, for: photo)
        }
    }

    private var shadowColor: Color {
        if UITraitCollection.current.userInterfaceStyle == .dark {
            return Color.black.opacity(0.6)
        } else {
            return Color.black.opacity(0.15)
        }
    }
}

