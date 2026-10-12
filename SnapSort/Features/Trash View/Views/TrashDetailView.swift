//
//  TrashDetailView.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 05/02/25.
//

import SwiftUI
import Photos

/// Full-screen view of a trashed photo with Restore / Delete actions
struct TrashDetailView: View {
    let asset: PHAsset
    let onRestore: () -> Void
    /// Returns true once the photo has actually been deleted
    let onDelete: () async -> Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PhotoDetailView(asset: asset) {
            Button("Restore") {
                onRestore()
                dismiss()
            }
            Spacer()
            Button("Delete", role: .destructive) {
                Task {
                    if await onDelete() {
                        dismiss()
                    }
                }
            }
        }
    }
}
