//
//  HapticManager.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import UIKit

protocol HapticServiceProtocol: ObservableObject {
    func prepare()
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType)
}

final class HapticService: HapticServiceProtocol, ObservableObject {
    private var generators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    
    func prepare() {
        generators.values.forEach { $0.prepare() }
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = generators[style] ?? UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        generators[style] = generator
    }
    
    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
