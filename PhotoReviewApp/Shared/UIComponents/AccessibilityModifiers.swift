//
//  AccessibilityModifiers.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 05/02/25.
//
import SwiftUI

struct AccessibleCard: ViewModifier {
    let label: String
    let hint: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
    }
}

extension View {
    func accessibleCard(label: String, hint: String = "") -> some View {
        modifier(AccessibleCard(label: label, hint: hint))
    }
}
