import SwiftUI
import TrailMarkCH10Core

struct WristMemoView: View {
    @Environment(WatchModel.self) private var model
    
    @State private var recorder = AudioRecorder()
    @State private var player = AudioPlayer()
    
    var body: some View {
        List {
            Section {
                Button {
                    recorder.isRecording ? finish() : start()
                } label: {
                    Label(
                        recorder.isRecording ? "Stop \(elapsed)" : "Record",
                        systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                    )
                    .foregroundStyle(recorder.isRecording ? .red : .accentColor)
                }
            }
            
            Section("Memos") {
                if model.media.memos.isEmpty {
                    Text("No memos recorded yet").foregroundStyle(.secondary)
                } else {
                    ForEach(model.media.memos) { memo in
                        Button {
                            player.play(url: model.media.url(for: memo))
                        } label: {
                            HStack {
                                Image(systemName: "play.circle")
                                VStack(alignment: .leading) {
                                    Text(memo.title).font(.caption)
                                        .lineLimit(1)
                                    Text(memo.durationText).font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Voice Memo")
        .task(id: recorder.isRecording) {
            while recorder.isRecording && !Task.isCancelled {
                recorder.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    private func start() {
        try? recorder.start()
    }
    
    private func finish() {
        guard let result = recorder.stop() else { return }
        model.saveAndSync(memoFrom: result.url, duration: result.duration)
    }
    
    private var elapsed: String {
        let seconds = Int(recorder.elapsedTime)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
