import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var haptic: HapticService
    @Environment(\.colorScheme) var colorScheme
    @State private var showTrashConfirmation = false
    @State private var showSaveConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    notificationsSection
                    reviewPreferencesSection
                    repetitionSection
                    deletionSection

                    // Add bottom spacer to ensure content isn't covered
                    Color.clear.frame(height: 60)
                }
                .padding(.vertical, AppSpacing.sectionSpacing)
                .padding(.horizontal, AppSpacing.md)
                // Add the overlay directly to the VStack
                .overlay(
                    saveConfirmationOverlay
                        .padding(.bottom, AppSpacing.lg),
                    alignment: .bottom
                )
            }
            .background(AppColors.groupedBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        performSave()
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundColor(settings.hasUnsavedChanges ? .white : AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(
                                settings.hasUnsavedChanges
                                ? AppColors.primary
                                : Color(.quaternarySystemFill)
                            )
                            .clipShape(Capsule())
                    }
                    .disabled(!settings.hasUnsavedChanges)
                    .buttonStyle(.plain)
                }
            }
        }
        .tint(AppColors.primary)
        .alert("Confirm Deletion", isPresented: $showTrashConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                settings.emptyTrash()
            }
        } message: {
            Text("Are you sure you want to permanently delete all items in the trash?")
        }
    }
    // MARK: - Sections
    
    private var notificationsSection: some View {
        SectionCard(
            title: LocalizedStrings.notificationsSection,
            icon: "bell.badge.fill",
            color: AppColors.primary
        ) {
            VStack(spacing: 0) {
                Toggle(isOn: $settings.isNotificationsEnabled) {
                    SettingRow(icon: "bell",
                               title: LocalizedStrings.notificationsSection,
                               iconColor: AppColors.primary)
                }
                .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                .padding(.vertical, AppSpacing.sm)
                .dynamicTypeSize(.medium ... .accessibility2)
                
                if settings.isNotificationsEnabled {
                    Divider()
                    SettingRow(icon: "clock",
                               title: LocalizedStrings.notificationBody,
                               iconColor: AppColors.primary) {
                        DatePicker(
                            "",
                            selection: $settings.notificationTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    }
                               .padding(.vertical, AppSpacing.sm)
                               .dynamicTypeSize(.medium ... .accessibility2)
                } else {
                    Divider()
                    Text("— \(LocalizedStrings.notificationBody)")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.vertical, AppSpacing.sm)
                        .dynamicTypeSize(.medium ... .accessibility2)
                }
            }
        }
    }
    
    private var reviewPreferencesSection: some View {
        SectionCard(
            title: LocalizedStrings.settingsTitle,
            icon: "photo.on.rectangle.angled",
            color: AppColors.success
        ) {
            VStack(spacing: 0) {
                SettingRow(icon: "externaldrive.badge.plus",
                           title: "Storage Target",
                           iconColor: AppColors.success) {
                    StorageTargetStepper(
                        value: $settings.storageTarget,
                        onIncrement: { haptic.impact(.light) },
                        onDecrement: { haptic.impact(.light) }
                    )
                }
                           .padding(.vertical, AppSpacing.sm)
                           .dynamicTypeSize(.medium ... .accessibility2)

                Divider()

                SettingRow(icon: "arrow.up.arrow.down",
                           title: "Sorting Method",
                           iconColor: AppColors.success) {
                    Picker("", selection: $settings.sortOption) {
                        ForEach(PhotoSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue.capitalized).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: settings.sortOption) { haptic.impact(.medium) }
                }
                           .padding(.vertical, AppSpacing.sm)
                           .dynamicTypeSize(.medium ... .accessibility2)
            }
        }
    }
    
    private var repetitionSection: some View {
        SectionCard(
            title: "Repetition Schedule",
            icon: "repeat",
            color: AppColors.warning
        ) {
            VStack(spacing: 0) {
                SettingRow(icon: "calendar",
                           title: "Repeat Schedule",
                           iconColor: AppColors.warning) {
                    Picker("", selection: $settings.repeatInterval) {
                        ForEach(RepeatInterval.allCases, id: \.self) { interval in
                            Text(interval.rawValue.capitalized).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: settings.repeatInterval) { haptic.impact(.medium) }
                }
                           .padding(.vertical, AppSpacing.sm)
                           .dynamicTypeSize(.medium ... .accessibility2)

                switch settings.repeatInterval {
                case .weekly:
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Divider()
                        Text("Selected Days")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                            .dynamicTypeSize(.medium ... .accessibility2)
                        WeekdaySelectionView(selection: $settings.selectedWeeklyDays)
                    }
                    .padding(.vertical, AppSpacing.sm)

                case .monthly:
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Divider()
                        Text("Day of Month")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                            .dynamicTypeSize(.medium ... .accessibility2)
                        MonthDaySelectionView(selection: $settings.selectedMonthlyDay)
                    }
                    .padding(.vertical, AppSpacing.sm)
                    
                default:
                    EmptyView()
                }
            }
            .transition(.opacity)
        }
    }
    
    private var deletionSection: some View {
        SectionCard(
            title: "Deletion Settings",
            icon: "trash.fill",
            color: AppColors.danger
        ) {
            VStack(spacing: 0) {
                SettingRow(icon: "exclamationmark.shield",
                           title: "Notice PopUp",
                           iconColor: AppColors.danger) {
                    Toggle("", isOn: $settings.showDeletionConfirmation)
                        .toggleStyle(SwitchToggleStyle(tint: AppColors.danger))
                        .onChange(of: settings.showDeletionConfirmation) { haptic.impact(.light) }
                }
                           .padding(.vertical, AppSpacing.sm)
                           .dynamicTypeSize(.medium ... .accessibility2)
                
                Divider()
                
                Button(role: .destructive) {
                    haptic.impact(.heavy)
                    showTrashConfirmation = true
                } label: {
                    SettingRow(icon: "trash",
                               title: "Empty Trash Now",
                               iconColor: AppColors.danger)
                }
                .buttonStyle(.plain)
                .padding(.vertical, AppSpacing.sm)
                .accessibilityLabel("Empty Trash Now")
            }
        }
    }
    
    // MARK: – Overlays
    
    private var saveConfirmationOverlay: some View {
        Group {
            if showSaveConfirmation {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColors.success)
                    Text("Settings Saved")
                        .font(AppTypography.labelLarge)
                }
                .padding(.vertical, AppSpacing.sm)
                .padding(.horizontal, AppSpacing.lg)
                .background(
                    Capsule()
                        .fill(.regularMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 8, y: 2)
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.appSpring, value: showSaveConfirmation)
    }
    
    // MARK: – Actions
    
    private func performSave() {
        haptic.notify(.success)
        settings.saveSettings()
        showSaveConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSaveConfirmation = false
        }
    }
}
