//
//  SettingsRowModifier.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 16/06/25.
//

import SwiftUI

extension View {
    func settingsRow() -> some View {
        self
            .padding(AppSpacing.md)
            .background(AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous))
            .appShadow(AppSpacing.shadowSmall)
    }
}
