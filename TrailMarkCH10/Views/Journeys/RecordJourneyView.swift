import SwiftUI
import MapKit
import TrailMarkCH10Core

struct RecordJourneyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var startedAt: Date?
    /// Created at start so the watch workout can be tagged with the journey it tracks.
    @State private var journeyID = UUID()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Map {
                    if !model.location.track.isEmpty {
                        MapPolyline(coordinates: model.location.track.coordinates)
                            .stroke(.orange, lineWidth: 4)
                    }
                    UserAnnotation()
                }
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack(spacing: 4) {
                    Text(distanceText).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("\(model.location.track.points.count) points recorded")
                        .font(.caption).foregroundStyle(.secondary)
                    if model.location.isLocationBeingRecorded {
                        Label("Workout tracking on Apple Watch", systemImage: "applewatch")
                            .font(.caption).foregroundStyle(.green)
                    }
                }
                
                if !model.location.isLocationBeingRecorded {
                    TextField("Journey Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button {
                    model.location.isLocationBeingRecorded ? stop() : start()
                } label: {
                    Text(model.location.isLocationBeingRecorded ? "Stop & Save" : "Start Journey")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            model.location.isLocationBeingRecorded ? Color.red : Color.accentColor,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .foregroundColor(.white)
                }
            }
            .padding()
            .navigationTitle("New Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if model.location.isLocationBeingRecorded {
                            _ = model.location.stopRecordingRoute()
                            model.endWorkout(for: journeyID)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear { model.location.requestWhenInUseAuthorization() }
        }
    }
    
    private var distanceText: String {
        Measurement(value: model.location.track.distanceMeters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
    
    private func start() {
        startedAt = Date()
        model.location.startRecordingRoute()
        model.startWorkout(for: journeyID)
    }
    
    private func stop() {
        let track = model.location.stopRecordingRoute()
        let start = startedAt ?? Date()
        let end = Date()
        
        let memoIDs = model.media.memos
            .filter { $0.createdAt >= start && $0.createdAt <= end }
            .map(\.id)
        
        let journey = Journey(
            id: journeyID,
            title: title.isEmpty ? "Untitled Journey" : title,
            startedAt: start,
            endedAt: end,
            track: track,
            memoIDs: memoIDs
        )
        
        model.journeyStore.add(journey)
        // The workout data lives on the watch: ending it there sends the finished
        // record back, and AppModel attaches it to this journey by ID.
        model.endWorkout(for: journeyID)
        
        dismiss()
    }

}

