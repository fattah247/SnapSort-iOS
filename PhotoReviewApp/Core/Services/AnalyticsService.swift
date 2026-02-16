//
//  AnalyticsStore.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import Foundation
import CoreData
import WidgetKit

protocol AnalyticsServiceProtocol {
    var totalStorageSaved: Int64 { get }
    var currentStreak: Int { get }
    var totalReviewed: Int64 { get }
    var totalDeleted: Int64 { get }
    var totalBookmarked: Int64 { get }
    
    func trackDeletion(fileSize: Int64)
    func trackBookmark()
    func trackReview()
    func resetStreak()
}

final class CoreDataAnalyticsService: ObservableObject, AnalyticsServiceProtocol {
    private let context: NSManagedObjectContext
    private var analyticsEntity: AnalyticsEntity?
    
    init(context: NSManagedObjectContext) {
        self.context = context
        loadAnalytics()
    }
    
    private func loadAnalytics() {
        let request: NSFetchRequest<AnalyticsEntity> = AnalyticsEntity.fetchRequest()
        do {
            analyticsEntity = try context.fetch(request).first ?? AnalyticsEntity(context: context)
            try context.save()
        } catch {
            AppLogger.coreData.error("Error loading analytics: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    var totalStorageSaved: Int64 { analyticsEntity?.totalStorageSaved ?? 0 }
    var currentStreak: Int { Int(analyticsEntity?.currentStreak ?? 0) }
    var totalReviewed: Int64 { analyticsEntity?.totalReviewed ?? 0 }
    var totalDeleted: Int64 { analyticsEntity?.totalDeleted ?? 0 }
    var totalBookmarked: Int64 { analyticsEntity?.totalBookmarked ?? 0 }
    
    func trackDeletion(fileSize: Int64) {
        analyticsEntity?.totalStorageSaved += fileSize
        analyticsEntity?.totalDeleted += 1
        saveContext()
    }
    
    func trackBookmark() {
        analyticsEntity?.totalBookmarked += 1
        saveContext()
    }
    
    func trackReview() {
        analyticsEntity?.totalReviewed += 1
        analyticsEntity?.currentStreak += 1
        saveContext()
    }
    
    func resetStreak() {
        analyticsEntity?.currentStreak = 0
        saveContext()
    }
    
    private func saveContext() {
        do {
            try context.save()
            syncToSharedDefaults()
        } catch {
            AppLogger.coreData.error("Error saving analytics: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func syncToSharedDefaults() {
        guard let defaults = UserDefaults(suiteName: Constants.AppGroup.identifier) else { return }
        defaults.set(currentStreak, forKey: Constants.SharedDefaults.streak)
        defaults.set(Int(totalStorageSaved), forKey: Constants.SharedDefaults.storageSaved)
        defaults.set(Int(totalReviewed), forKey: Constants.SharedDefaults.totalReviewed)
        defaults.set(Int(totalDeleted), forKey: Constants.SharedDefaults.totalDeleted)
        defaults.set(Int(totalBookmarked), forKey: Constants.SharedDefaults.totalBookmarked)
        WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widget.kind)
    }
}
