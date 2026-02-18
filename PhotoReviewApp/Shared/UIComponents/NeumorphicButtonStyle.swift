//
//  NeumorphicButtonStyle.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 16/06/25.
//

import SwiftUI

struct NeumorphicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(AppSpacing.md)
            .background(
                Group {
                    if configuration.isPressed {
                        Color(.systemGray5)
                    } else {
                        AppColors.cardBackground
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            .appShadow(configuration.isPressed ? AppSpacing.shadowSmall : AppSpacing.shadowMedium)
    }
}
