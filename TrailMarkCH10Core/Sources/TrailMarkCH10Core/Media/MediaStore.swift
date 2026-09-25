import Foundation
import AVFoundation // Tool box to deal with media (audio and video)
import CoreLocation
import Observation

@MainActor
@Observable
public final class MediaStore {
    // This observable variable is mostly for the UI to access in order to keep the app responsive
    public private(set) var memos: [MediaMemo] = []
    
    private let fileManager = FileManager.default
    private let indexFileName = "memos.json"
    
    public init() {
        loadIndexData()
    }
    
    // MARK: - File Manager Locations

    // We will define a specific location (unmutable)
    public var mediaDirectory: URL {
        let base = fileManager.urls(for: .applicationDirectory, in: .userDomainMask)[0] // ramsesg/home/trailmarkch10
        let dir = base.appendingPathComponent("Media", isDirectory: true) // ramsesg/home/trailmarkch10/Media
        
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return dir
    }
    
    private var indexURL: URL {
        mediaDirectory.appendingPathComponent(indexFileName) // -> // ramsesg/home/trailmarkch10/memos.json
    }
    
    public func url(for memo: MediaMemo) -> URL {
        mediaDirectory.appendingPathComponent(memo.fileName) // -> ramsesg/home/trailmarkch10/Media/example.m4a
    }
    
    // MARK: - Saving Functions
    @discardableResult
    public func add(
        kind: MemoKind,
        movingFileFrom sourceURL: URL,
        duration: TimeInterval,
        title: String = "",
        coordinate: CLLocationCoordinate2D? = nil
    ) throws -> MediaMemo {
        let id = UUID()
        let ext = sourceURL.pathExtension.isEmpty ? (kind == .audio ? "m4a" : "mov") : sourceURL.pathExtension
        let fileName = "\(id.uuidString).\(ext)" // asdhgjashjd-23423-asdasd324-asd3443.m4a
        let destination = mediaDirectory.appendingPathComponent(fileName)
        
        // sanity check in case file already exists
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }
        
        try? fileManager.moveItem(at: sourceURL, to: destination)
        
        var memo = MediaMemo(
            id: id,
            kind: kind,
            fileName: fileName,
            duration: duration,
            title: title
        )
        
        memo.setCoordinate(coordinate)
        
        memos.insert(memo, at: 0)
        persistIndex()
        return memo
    }

    /// Adds a memo whose file is already sitting in `mediaDirectory` — e.g. one that
    /// just arrived from the watch. Re-registering the same ID replaces it.
    public func register(_ memo: MediaMemo) {
        memos.removeAll { $0.id == memo.id }
        memos.append(memo)
        memos.sort { $0.createdAt > $1.createdAt }
        persistIndex()
    }

    
    private func loadIndexData() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoded = (try? JSONDecoder().decode([MediaMemo].self, from: data)) ?? []
        
        memos = decoded.sorted { $0.createdAt > $1.createdAt }
    }
    
    private func persistIndex() {
        guard let data = try? JSONEncoder().encode(memos) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
