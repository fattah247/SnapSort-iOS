//
//  HapticsLabView.swift
//  SnapSort
//
//  Debug-only screen for feeling and tuning haptics on a real iPhone.
//  The Simulator can't play haptics.
//

#if DEBUG
import SwiftUI
import UIKit

struct HapticsLabView: View {
    @EnvironmentObject private var haptics: Haptics

    @State private var intensity: Float = 0.5
    @State private var sharpness: Float = 0.5
    @State private var didCopy = false
    @State private var dragX: CGFloat = 0
    @State private var zone = SwipeZoneTracker()

    var body: some View {
        Form {
            patternsSection
            tapSection
            swipeSection
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.groupedBackground)
        .navigationTitle("Haptics Lab")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Patterns

    private var patternsSection: some View {
        Section {
            ForEach(HapticPattern.all, id: \.self) { pattern in
                Button {
                    haptics.play(pattern)
                } label: {
                    LabeledContent {
                        Text(pattern.isSystem ? "iOS" : "\(Int((pattern.duration * 1000).rounded())) ms")
                            .monospacedDigit()
                    } label: {
                        Text(pattern.labName)
                        Text(pattern.labDetail)
                    }
                }
                .tint(.primary)
            }
        } header: {
            Text("Patterns")
        } footer: {
            Text(haptics.isEnabled
                 ? "Tap a row to feel it. Haptics only play on an iPhone."
                 : "Haptics are off in Settings, so nothing will play.")
        }
    }

    // MARK: - Single Tap

    private var tapSection: some View {
        Section {
            LabeledContent("Intensity \(intensity.formatted(.number.precision(.fractionLength(2))))") {
                Slider(value: $intensity, in: 0...1)
                    .frame(maxWidth: 180)
            }
            LabeledContent("Sharpness \(sharpness.formatted(.number.precision(.fractionLength(2))))") {
                Slider(value: $sharpness, in: 0...1)
                    .frame(maxWidth: 180)
            }
            Button("Play Tap") {
                haptics.playTap(intensity: intensity, sharpness: sharpness)
            }
            Button(didCopy ? "Copied" : "Copy Values") {
                UIPasteboard.general.string = String(
                    format: "intensity %.2f, sharpness %.2f", intensity, sharpness
                )
                didCopy = true
            }
        } header: {
            Text("Single Tap")
        } footer: {
            Text("Find a tap you like, then copy its values to send them over.")
        }
    }

    // MARK: - Swipe Zones

    private var swipeSection: some View {
        Section {
            GeometryReader { proxy in
                let threshold = proxy.size.width * 0.3
                ZStack {
                    zoneLine(AppColors.delete).offset(x: -threshold)
                    zoneLine(AppColors.keep).offset(x: threshold)

                    RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                        .fill(AppColors.placeholder)
                        .frame(width: 84, height: 104)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .offset(x: dragX)
                        .rotationEffect(.degrees(Double(dragX) / 25), anchor: .bottom)
                        .gesture(swipeGesture(threshold: threshold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 150)
        } header: {
            Text("Swipe Zones")
        } footer: {
            Text("Drag past a line to feel the detent, back to feel it release. Let go past a line for bookmark or trash.")
        }
    }

    private func zoneLine(_ color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: 3, height: 120)
    }

    private func swipeGesture(threshold: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragX = value.translation.width
                if let feedback = zone.update(offset: dragX, threshold: threshold) {
                    haptics.play(feedback)
                }
            }
            .onEnded { value in
                zone.reset()
                let width = value.translation.width
                if abs(width) > threshold {
                    haptics.play(width > 0 ? .bookmark : .trash)
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    dragX = 0
                }
            }
    }
}

private extension HapticPattern {
    var labName: String {
        switch self {
        case .detent(.right): "Detent, bookmark side"
        case .detent(.left): "Detent, trash side"
        case .release: "Release"
        case .bookmark: "Bookmark"
        case .trash: "Trash"
        case .skip: "Skip"
        case .undo: "Undo"
        case .bulkTrash(let count): "Bulk trash (\(count))"
        case .confirm: "Confirm"
        case .restore: "Restore"
        case .press: "Button press"
        case .celebrate: "Celebrate"
        case .system(.selection): "System selection"
        case .system(.success): "System success"
        case .system(.error): "System error"
        }
    }

    var labDetail: String {
        switch self {
        case .detent: "Dragging into a swipe zone"
        case .release: "Leaving a zone, removing a bookmark"
        case .bookmark: "Rising ding-ding"
        case .trash: "Thunk into the bin"
        case .skip: "Neutral nudge"
        case .undo: "Falling rewind"
        case .bulkTrash: "Similar Shots, a person's photos"
        case .confirm: "Keep All, Haptics turned on"
        case .restore: "Back from the Trash"
        case .press: "Chunky buttons, on touch-down"
        case .celebrate: "Milestones and session goals"
        case .system(.selection): "Selecting items"
        case .system(.success): "Photos deleted from the library"
        case .system(.error): "Delete failed"
        }
    }
}

#Preview {
    NavigationStack {
        HapticsLabView()
    }
    .environmentObject(Haptics())
}
#endif
