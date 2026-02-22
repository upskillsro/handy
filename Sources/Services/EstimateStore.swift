import SwiftData
import Foundation
import SwiftUI

@Model
class TaskMetadata {
    @Attribute(.unique) var id: String // Matches EKReminder.calendarItemIdentifier
    var estimatedDuration: TimeInterval // in seconds
    var timeSpent: TimeInterval // in seconds
    var tags: [String] // e.g., ["Today", "DeepWork"]
    var lastUpdated: Date
    
    init(id: String, estimatedDuration: TimeInterval = 0, timeSpent: TimeInterval = 0, tags: [String] = []) {
        self.id = id
        self.estimatedDuration = estimatedDuration
        self.timeSpent = timeSpent
        self.tags = tags
        self.lastUpdated = Date()
    }
}

@MainActor
class EstimateStore: ObservableObject {
    @Published private(set) var lastSaveError: String?
    
    // Phase 1: In-Memory Cache
    private var metadataCache: [String: TaskMetadata] = [:]
    
    // Granular Observers
    // We keep a cache of ObservableObjects for individual tasks. 
    // Views subscribe to these instead of the global store.
    class TaskEstimates: ObservableObject {
        @Published var timeSpent: TimeInterval
        @Published var estimatedDuration: TimeInterval
        
        init(timeSpent: TimeInterval, estimatedDuration: TimeInterval) {
            self.timeSpent = timeSpent
            self.estimatedDuration = estimatedDuration
        }
    }
    
    private var observerCache: [String: TaskEstimates] = [:]
    
    var container: ModelContainer?
    
    init() {
        do {
            container = try ModelContainer(for: TaskMetadata.self)
            loadCache()
        } catch {
            AppLogger.estimate.error("Failed to create ModelContainer: \(String(describing: error), privacy: .public)")
        }
    }
    
    private func loadCache() {
        guard let container = container else { return }
        let context = container.mainContext
        let descriptor = FetchDescriptor<TaskMetadata>()
        
        do {
            let results = try context.fetch(descriptor)
            self.metadataCache = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
            
            // Pre-warm observers if needed (lazy is better usually, but clean)
        } catch {
            AppLogger.estimate.error("Failed to load cache: \(String(describing: error), privacy: .public)")
        }
    }
    
    // Get the granular observer for a specific ID
    func getEstimates(for id: String) -> TaskEstimates {
        if let existing = observerCache[id] {
            return existing
        }
        
        // Create new
        let metadata = metadataCache[id]
        let newObserver = TaskEstimates(
            timeSpent: metadata?.timeSpent ?? 0,
            estimatedDuration: metadata?.estimatedDuration ?? 0
        )
        observerCache[id] = newObserver
        return newObserver
    }
    
    // Legacy/Direct Access (Non-observing)
    func getMetadata(for id: String) -> TaskMetadata? {
        return metadataCache[id]
    }
    
    func updateEstimate(for id: String, duration: TimeInterval) {
        guard let container = container else { return }
        let context = container.mainContext
        
        if let metadata = metadataCache[id] {
            metadata.estimatedDuration = duration
            metadata.lastUpdated = Date()
        } else {
            let newMetadata = TaskMetadata(id: id, estimatedDuration: duration)
            context.insert(newMetadata)
            metadataCache[id] = newMetadata
        }
        
        // Update Observer
        observerCache[id]?.estimatedDuration = duration
        
        save(context: context, operation: "update estimate")
        objectWillChange.send() // Re-enabled: Needed for SideStripView header stats
    }
    
    func setTimeSpent(for id: String, seconds: TimeInterval) {
        guard let container = container else { return }
        let context = container.mainContext
        
        if let metadata = metadataCache[id] {
            metadata.timeSpent = seconds
            metadata.lastUpdated = Date()
        } else {
            let newMetadata = TaskMetadata(id: id, timeSpent: seconds)
            context.insert(newMetadata)
            metadataCache[id] = newMetadata
        }
        
        // Update Observer
        observerCache[id]?.timeSpent = seconds
        
        save(context: context, operation: "set time spent")
        objectWillChange.send() // Re-enabled: Needed for SideStripView header stats
    }
    
    func addTimeSpent(for id: String, seconds: TimeInterval) {
        let current = metadataCache[id]?.timeSpent ?? 0
        setTimeSpent(for: id, seconds: current + seconds)
    }
    
    private func save(context: ModelContext, operation: String) {
        do {
            try context.save()
            lastSaveError = nil
        } catch {
            let message = "Failed to \(operation): \(error)"
            lastSaveError = message
            AppLogger.estimate.error("\(message, privacy: .public)")
        }
    }
}
