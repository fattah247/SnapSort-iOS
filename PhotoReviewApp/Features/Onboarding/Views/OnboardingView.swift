//
//  OnboardingView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import SwiftUI
import Photos
import CoreData
import OSLog

struct OnboardingView: View {
    @EnvironmentObject var photoService: PhotoLibraryService
    @EnvironmentObject var notificationService: NotificationService

    @State private var currentPage = 0
    @State private var photoAccessGranted = false
    @State private var notificationsGranted = false

    private let totalPages = 4

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [AppColors.primary.opacity(0.05), AppColors.groupedBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                    .padding(.top, AppSpacing.lg)

                // Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    permissionsPage.tag(1)
                    notificationsPage.tag(2)
                    completionPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.appSpring, value: currentPage)
            }
        }
    }

    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index <= currentPage ? AppColors.primary : AppColors.primary.opacity(0.2))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.appSpring, value: currentPage)
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Welcome Page
    private var welcomePage: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.primaryGradient)
                    .frame(width: 120, height: 120)

                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            VStack(spacing: AppSpacing.sm) {
                Text("Welcome to")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textSecondary)

                Text("Photo Review")
                    .font(AppTypography.displayLarge)
                    .foregroundColor(AppColors.textPrimary)
            }

            Text("Quickly organize your photo library with simple swipe gestures. Keep what you love, remove what you don't.")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Spacer()

            // Feature highlights
            VStack(spacing: AppSpacing.md) {
                FeatureRow(icon: "hand.draw", title: "Swipe to Decide", description: "Right to keep, left to delete")
                FeatureRow(icon: "bookmark", title: "Save Favorites", description: "Bookmark photos you love")
                FeatureRow(icon: "chart.bar", title: "Track Progress", description: "See your organization stats")
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()

            continueButton(action: { withAnimation { currentPage = 1 } })
                .padding(.bottom, AppSpacing.xl)
        }
        .padding(AppSpacing.lg)
    }

    // MARK: - Permissions Page
    private var permissionsPage: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.bookmark.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 50))
                    .foregroundColor(AppColors.bookmark)
            }

            VStack(spacing: AppSpacing.sm) {
                Text("Photo Access")
                    .font(AppTypography.displaySmall)
                    .foregroundColor(AppColors.textPrimary)

                Text("We need access to your photos to help you organize them. Your photos never leave your device.")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }

            Spacer()

            // Privacy note
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.success)

                Text("Your photos are processed locally and never uploaded anywhere.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.success.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            .padding(.horizontal, AppSpacing.lg)

            Spacer()

            VStack(spacing: AppSpacing.sm) {
                Button(action: {
                    Task {
                        let status = await photoService.requestAuthorization()
                        photoAccessGranted = status == .authorized || status == .limited
                        AppLogger.general.info("Photo access: \(String(describing: status))")
                        if photoAccessGranted {
                            withAnimation { currentPage = 2 }
                        }
                    }
                }) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: photoAccessGranted ? "checkmark.circle.fill" : "photo")
                        Text(photoAccessGranted ? "Access Granted" : "Grant Photo Access")
                    }
                    .font(AppTypography.button)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(photoAccessGranted ? AppColors.success : AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                }

                Button("Skip for now") {
                    withAnimation { currentPage = 2 }
                }
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(AppSpacing.lg)
    }

    // MARK: - Notifications Page
    private var notificationsPage: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.streak.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AppColors.streak)
            }

            VStack(spacing: AppSpacing.sm) {
                Text("Stay on Track")
                    .font(AppTypography.displaySmall)
                    .foregroundColor(AppColors.textPrimary)

                Text("Get gentle reminders to review your photos and build a daily habit of organization.")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }

            Spacer()

            // Sample notification preview
            notificationPreview
                .padding(.horizontal, AppSpacing.lg)

            Spacer()

            VStack(spacing: AppSpacing.sm) {
                Button(action: {
                    Task {
                        let granted = await notificationService.requestAuthorization()
                        notificationsGranted = granted
                        AppLogger.general.info("Notifications: \(granted)")
                        withAnimation { currentPage = 3 }
                    }
                }) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: notificationsGranted ? "checkmark.circle.fill" : "bell")
                        Text(notificationsGranted ? "Enabled" : "Enable Notifications")
                    }
                    .font(AppTypography.button)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(notificationsGranted ? AppColors.success : AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
                }

                Button("Skip for now") {
                    withAnimation { currentPage = 3 }
                }
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(AppSpacing.lg)
    }

    private var notificationPreview: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "app.badge")
                .font(.system(size: 32))
                .foregroundColor(AppColors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Photo Review Time")
                    .font(AppTypography.labelMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("It's time to review your memories!")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text("now")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
    }

    // MARK: - Completion Page
    private var completionPage: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.successGradient)
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: AppSpacing.sm) {
                Text("You're All Set!")
                    .font(AppTypography.displaySmall)
                    .foregroundColor(AppColors.textPrimary)

                Text("Start organizing your photo library with simple swipes.")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }

            Spacer()

            // Quick tips
            VStack(spacing: AppSpacing.sm) {
                TipRow(icon: "arrow.left", text: "Swipe left to delete")
                TipRow(icon: "arrow.right", text: "Swipe right to bookmark")
                TipRow(icon: "arrow.down", text: "Skip to review later")
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()

            NavigationLink {
                MainTabView()
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text("Get Started")
                    Image(systemName: "arrow.right")
                }
                .font(AppTypography.button)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(AppSpacing.lg)
    }

    // MARK: - Helper Views
    private func continueButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Text("Continue")
                Image(systemName: "arrow.right")
            }
            .font(AppTypography.button)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
        }
        .padding(.horizontal, AppSpacing.lg)
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.labelMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text(description)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Tip Row
struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.primary)
                .frame(width: 24)

            Text(text)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)

            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
    }
}
