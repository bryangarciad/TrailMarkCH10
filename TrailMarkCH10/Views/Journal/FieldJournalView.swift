import SwiftUI
import TrailMarkCH10Core

struct FieldJournalView: View {
    @Environment(AppModel.self) private var model
    
    @State private var showingAudioRecorder = false
    @State private var showingVideoPicker = false
    
    var body: some View {
        NavigationStack {
            Group {
                if model.media.memos.isEmpty {
                    ContentUnavailableView(
                        "No memos yet",
                        systemImage: "Waveform",
                        description:  Text("Record a voice or video memo to start your journey")
                    )
                } else {
                    List {
                        ForEach(model.media.memos) { memo in
                            NavigationLink(value: memo) {
                                MemoRow(memo: memo)
                            }
                        }
                        // TODO: Go back and implement delete
                    }
                }
            }
            .navigationTitle("Field Journal")
            .navigationDestination(for: MediaMemo.self) { memo in
                MemoDetailsView(memo: memo)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showingVideoPicker = true } label: {
                        Image(systemName: "video.badge.plus")
                    }
                    Button { showingAudioRecorder = true } label: {
                        Image(systemName: "mic.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAudioRecorder) {
                RecordAudioView()
            }
            .sheet(isPresented: $showingVideoPicker) {
                VideoCaptureView { url, duration in
                    _ = try? model.media.add(
                        kind: .video,
                        movingFileFrom: url,
                        duration: duration,
                        coordinate: model.location.currentCoordinate
                    )
                }
            }
        }
    }
}

struct MemoRow: View {
    @Environment(AppModel.self) private var model

    let memo: MediaMemo
    
    // This will be to show for video only
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background.secondary)
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: memo.kind.symbolName)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 54, height: 54)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(memo.title).font(.headline).lineLimit(1)
                HStack(spacing: 8) {
                    Label(memo.durationText, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
