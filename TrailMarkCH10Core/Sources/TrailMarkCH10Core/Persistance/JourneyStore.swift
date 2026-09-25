import Foundation
import Observation

@MainActor
@Observable
public final class JourneyStore {
    public private(set) var journeys: [Journey] = []
    
    private let fileManager = FileManager.default
    
    public init() {
        load()
    }
    
    private var fileURL: URL {
        let basePath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return basePath.appendingPathComponent("journeys.json")
    }
    
    public func add(_ journey: Journey) {
        // if id already exists in the arr we are interpretating that as an UPDATE
        if let index = journeys.firstIndex(where: { $0.id == journey.id }) {
            journeys[index] = journey
        } else {
            journeys.insert(journey, at: 0) // ensure sorting DESC (new first)
        }
        
        journeys.sort { $0.startedAt > $1.startedAt }
        persist()
    }
    
    public func delete(_ journey: Journey) {
        journeys.removeAll { $0.id == journey.id }
        persist()
    }
    
    public func delete(at offsets: IndexSet) {
        offsets.map { journeys[$0] }.forEach(delete)
    }
    
    
    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoded = (try? JSONDecoder().decode([Journey].self, from: data)) ?? []
        
        // Decoded will not retain the sorting order, therefore we may want to sort it back
        journeys = decoded.sorted { $0.startedAt > $1.startedAt }
    }
    
    private func persist() {
        guard let data = try? JSONEncoder().encode(journeys) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
