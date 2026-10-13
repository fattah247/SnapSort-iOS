import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var analysisService: PhotoAnalysisService
    @EnvironmentObject var photoService: PhotoLibraryService
    @EnvironmentObject var haptics: Haptics
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var didResetTips = false
    @State private var showRescanConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    remindersSection
                    reviewingSection
                    smartSection
                    tipsSection
                    aboutSection
                }
                .listRowBackground(AppColors.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.groupedBackground)
            .navigationTitle("Settings")
            .confirmationDialog(
                "Re-scan your library?",
                isPresented: $showRescanConfirmation,
                titleVisibility: .visible
            ) {
                Button("Re-scan Library") {
                    analysisService.resetAndRescan(photoService: photoService)
                }
            } message: {
                Text("SnapSort will look through every photo again. This can take a while on big libraries.")
            }
            .task {
                await settings.refreshNotificationStatus()
            }
            .onChange(of: scenePhase) { _, phase in
                // The user may have changed notification permission in iOS Settings
                if phase == .active {
                    Task { await settings.refreshNotificationStatus() }
                }
            }
        }
    }

    // MARK: - Reminders

    private var remindersEnabled: Binding<Bool> {
        Binding(
            get: { settings.isNotificationsEnabled },
            set: { newValue in
                Task { await settings.setRemindersEnabled(newValue) }
            }
        )
    }

    private var remindersSection: some View {
        Section {
            Toggle(isOn: remindersEnabled) {
                SettingsLabel("Review Reminders", systemImage: "bell.fill", tint: AppColors.streak)
            }

            if settings.isNotificationsEnabled {
                DatePicker(
                    selection: $settings.notificationTime,
                    displayedComponents: .hourAndMinute
                ) {
                    SettingsLabel("Time", systemImage: "clock.fill", tint: AppColors.storage)
                }

                Picker(selection: $settings.repeatInterval) {
                    ForEach(RepeatInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                } label: {
                    SettingsLabel("Repeat", systemImage: "repeat", tint: AppColors.brand)
                }

                switch settings.repeatInterval {
                case .weekly:
                    NavigationLink {
                        WeekdaySelectionList(selection: $settings.selectedWeeklyDays)
                    } label: {
                        LabeledContent("Days", value: weekdaySummary)
                    }
                case .monthly:
                    Picker("Day of Month", selection: $settings.selectedMonthlyDay) {
                        ForEach(SettingsViewModel.monthDayRange, id: \.self) { day in
                            Text(day, format: .number).tag(day)
                        }
                    }
                default:
                    EmptyView()
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            if settings.notificationsDenied {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Notifications are turned off for SnapSort.")
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Button("Open Settings") { openURL(url) }
                            .font(.footnote)
                    }
                }
            } else {
                Text("Get a nudge to clear out a few photos.")
            }
        }
    }

    private var weekdaySummary: String {
        let selected = Set(settings.selectedWeeklyDays)
        let weekdays: Set<Weekday> = [.mon, .tue, .wed, .thu, .fri]
        switch selected {
        case []: return "None"
        case Set(Weekday.allCases): return "Every Day"
        case weekdays: return "Weekdays"
        case [.sat, .sun]: return "Weekends"
        default:
            return Weekday.localeOrdered
                .filter(selected.contains)
                .map(\.shortName)
                .joined(separator: ", ")
        }
    }

    // MARK: - Reviewing

    private var reviewingSection: some View {
        Section {
            Picker(selection: $settings.sortOption) {
                ForEach(PhotoSortOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            } label: {
                SettingsLabel("Photo Order", systemImage: "arrow.up.arrow.down", tint: AppColors.brand)
            }

            Stepper(
                value: $settings.storageTarget,
                in: SettingsViewModel.storageTargetRange,
                step: Int(SettingsViewModel.storageTargetStep)
            ) {
                // Not LabeledContent: inside a Stepper it splits the icon label
                // into a stacked title/subtitle
                HStack {
                    SettingsLabel("Session Goal", systemImage: "leaf.fill", tint: AppColors.brand)
                    Spacer(minLength: AppSpacing.xs)
                    Text(settings.storageTarget.storageText)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            // Otherwise VoiceOver reads the raw byte count
            .accessibilityValue(settings.storageTarget.storageText)

            Toggle(isOn: $settings.showDeletionConfirmation) {
                SettingsLabel("Confirm Before Trashing", systemImage: "trash.fill", tint: AppColors.delete)
            }

            Toggle(isOn: $haptics.isEnabled) {
                SettingsLabel("Haptics", systemImage: "iphone.radiowaves.left.and.right", tint: AppColors.people)
            }
            .onChange(of: haptics.isEnabled) { _, isOn in
                // A small taste of what was just turned on
                if isOn { haptics.play(.confirm) }
            }
        } header: {
            Text("Reviewing")
        } footer: {
            Text("A session wraps up once you've marked this much space for deletion. Trashed photos stay in your library until you empty the Trash.")
        }
    }

    // MARK: - Smart Analysis

    private var smartSection: some View {
        Section {
            LabeledContent {
                if analysisService.analysisProgress.isScanning {
                    ProgressView()
                } else {
                    Text("Up to date")
                }
            } label: {
                SettingsLabel("Library Scan", systemImage: "square.grid.2x2.fill", tint: AppColors.storage)
            }

            Button {
                showRescanConfirmation = true
            } label: {
                SettingsLabel("Re-scan Library", systemImage: "arrow.clockwise", tint: AppColors.people)
            }
            .disabled(analysisService.analysisProgress.isScanning)
        } header: {
            Text("Smart Groups")
        } footer: {
            Text("Smart groups are found on this device. New photos are checked whenever you open Smart.")
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        Section {
            Button {
                SwipeTutorialManager.reset()
                didResetTips = true
            } label: {
                SettingsLabel("Show Swipe Tips Again", systemImage: "hand.draw.fill", tint: AppColors.keep, foreground: AppColors.keepInk)
            }
            .disabled(didResetTips)
        } footer: {
            if didResetTips {
                Text("Tips will appear the next time you open Review.")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(appVersion)
            } label: {
                SettingsLabel("Version", systemImage: "info", tint: Color(.systemGray))
            }

            #if DEBUG
            NavigationLink {
                HapticsLabView()
            } label: {
                SettingsLabel("Haptics Lab", systemImage: "waveform.path", tint: Color(.systemGray))
            }
            #endif
        } footer: {
            Text("Photos are analyzed on this device and never uploaded.")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

// MARK: - Row Label

/// Settings-app style row label with a colored icon tile
private struct SettingsLabel: View {
    let title: String
    let systemImage: String
    let tint: Color
    var foreground: Color = .white

    init(_ title: String, systemImage: String, tint: Color, foreground: Color = .white) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.foreground = foreground
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .iconTile(tint, size: 28, foreground: foreground)
        }
    }
}

// MARK: - Weekday Selection

/// Multi-select list of weekdays, like the Clock app's Repeat screen
private struct WeekdaySelectionList: View {
    @Binding var selection: [Weekday]

    var body: some View {
        List {
            ForEach(Weekday.localeOrdered) { day in
                Button {
                    toggle(day)
                } label: {
                    HStack {
                        Text("Every \(Calendar.current.weekdaySymbols[day.rawValue - 1])")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selection.contains(day) {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .accessibilityAddTraits(selection.contains(day) ? .isSelected : [])
            }
        }
        .navigationTitle("Days")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ day: Weekday) {
        if let index = selection.firstIndex(of: day) {
            selection.remove(at: index)
        } else {
            selection.append(day)
        }
    }
}
