//
//  AnimationExtensions.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 05/02/25.
//
import SwiftUI

extension Animation {
    static let cardBounce = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let smoothFade = Animation.easeInOut(duration: 0.25)
    static let quickSnap = Animation.interactiveSpring(response: 0.15, dampingFraction: 0.86)
}

extension AnyTransition {
    static var cardTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(x: 0, y: 50).combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        )
    }
}
