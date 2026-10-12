//
//  OnboardingView.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import SwiftUI
import Photos
import OSLog

struct OnboardingView: View {
    let onFinish: () -> Void

    @EnvironmentObject var photoService: PhotoLibraryService
    @EnvironmentObject var settings: SettingsViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .welcome
    @State private var photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var isRequesting = false

    private enum Step {
        case welcome, photos, reminders
    }

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                welcomePage
                    .transition(pageTransition)
            case .photos:
                photosPage
                    .transition(pageTransition)
            case .reminders:
                remindersPage
                    .transition(pageTransition)
            }
        }
        .animation(.smooth, value: step)
        .background(AppColors.groupedBackground)
        .onChange(of: scenePhase) { _, phase in
            // Returning from iOS Settings
            if phase == .active {
                photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            }
        }
    }

    private var pageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        OnboardingPage(
            mood: .happy,
            title: "Hi, I'm Snappy!",
            message: "Let's make your camera roll a little tidier, one swipe at a time."
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureRow(
                    systemImage: "hand.draw.fill",
                    tint: AppColors.brand,
                    title: "Swipe to sort",
                    description: "Left to trash, right to bookmark. Undo anytime."
                )
                FeatureRow(
                    systemImage: "trash.fill",
                    tint: AppColors.delete,
                    title: "Delete when you're ready",
                    description: "Nothing leaves your library until you empty the Trash."
                )
                FeatureRow(
                    systemImage: "square.on.square",
                    tint: AppColors.storage,
                    title: "Find the clutter",
                    description: "Blurry shots, look-alikes, screenshots, and long videos."
                )
            }
            .padding(.top, AppSpacing.md)
        } actions: {
            primaryButton("Continue") { step = .photos }
        }
    }

    // MARK: - Photo Access

    private var photosPage: some View {
        let isBlocked = photoStatus == .denied || photoStatus == .restricted

        return OnboardingPage(
            mood: isBlocked ? .sleepy : .curious,
            title: isBlocked ? "Photo access is off" : "Can I take a peek?",
            message: isBlocked
                ? "Photo access is turned off for SnapSort. Turn it on in Settings to start reviewing."
                : "I'll show your photos one at a time so you can decide what to keep. Everything stays on this device."
        ) {
            EmptyView()
        } actions: {
            if isBlocked {
                primaryButton("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                secondaryButton("Not Now") { step = .reminders }
            } else {
                primaryButton("Continue") {
                    Task { await requestPhotoAccess() }
                }
                .disabled(isRequesting)
            }
        }
    }

    private func requestPhotoAccess() async {
        guard photoStatus == .notDetermined else {
            step = .reminders
            return
        }
        isRequesting = true
        defer { isRequesting = false }

        let status = await photoService.requestAuthorization()
        AppLogger.general.info("Photo access: \(String(describing: status))")
        photoStatus = status
        if status == .authorized || status == .limited {
            step = .reminders
        }
    }

    // MARK: - Reminders

    private var remindersPage: some View {
        OnboardingPage(
            mood: .happy,
            title: "Want a gentle nudge?",
            message: "A quick reminder in the evening keeps your library tidy. You can change this anytime in Settings."
        ) {
            EmptyView()
        } actions: {
            primaryButton("Turn On Reminders") {
                Task {
                    isRequesting = true
                    await settings.setRemindersEnabled(true)
                    isRequesting = false
                    onFinish()
                }
            }
            .disabled(isRequesting)
            secondaryButton("Not Now", action: onFinish)
        }
    }

    // MARK: - Buttons

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ChunkyLabel(title: title)
        }
        .buttonStyle(.chunky)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
    }
}

// MARK: - Page Layout

private struct OnboardingPage<Content: View, Actions: View>: View {
    let mood: Snappy.Mood
    let title: String
    let message: String
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Snappy(mood: mood, size: 132)
                        .padding(.top, AppSpacing.xl * 1.5)

                    VStack(spacing: AppSpacing.sm) {
                        Text(title)
                            .font(.largeTitle.bold())
                        Text(message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    content
                }
                .padding(.horizontal, AppSpacing.xl)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: AppSpacing.xs) {
                actions
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .frame(maxWidth: 520)
        }
    }
}

// MARK: - Feature Row
private struct FeatureRow: View {
    let systemImage: String
    let tint: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .iconTile(tint, size: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
