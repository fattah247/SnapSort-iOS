//
//  CoreDataManager.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import Foundation
import CoreData
import OSLog

final class CoreDataManager: NSObject, ObservableObject {
    static let shared = CoreDataManager()
    private let container: NSPersistentContainer
    private var mergeObserver: NSObjectProtocol?

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    private override init() {
        container = NSPersistentContainer(name: "PhotoReviewModel")
        super.init()  // Call super.init() first
        configureSecurity()
        loadStores()
        setupObservers()
    }

    deinit {
        if let mergeObserver {
            NotificationCenter.default.removeObserver(mergeObserver)
        }
    }

    private func configureSecurity() {
        let description = container.persistentStoreDescriptions.first

        // Set option for persistent history tracking
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    }

    private func loadStores() {
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data load error: \(error), \(error.userInfo)")
            }
        }
    }

    private func setupObservers() {
        mergeObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.viewContext.mergeChanges(fromContextDidSave: notification)
        }
    }
    
    func saveContext() async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                guard self.viewContext.hasChanges else {
                    continuation.resume()
                    return
                }
                
                do {
                    try self.viewContext.save()
                    continuation.resume()
                } catch {
                    AppLogger.coreData.error("Core Data save failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume()
                }
            }
        }
    }
}
