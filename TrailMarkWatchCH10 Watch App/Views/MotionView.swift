import SwiftUI
import TrailMarkCH10Core

struct MotionView: View {
    @Environment(WatchModel.self) private var model
    
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: model.motion.activity.symbolName)
                        .font(.title2)
                        .foregroundStyle(.teal)
                    
                    Text(model.motion.activity.label)
                        .font(.headline)
                }
            } header: {
                Text("Current Activity")
            }
            
            Section {
                LabeledContent("Cadence", value: "\(Int(model.motion.cadence)) spm")
                LabeledContent("Steps", value: "\(model.motion.stepsToday)")
                LabeledContent("Accel M.", value: String(format: "%.2f", model.motion.accMagnitude))
            } header: {
                Text("Raw Data/Signals")
            }
        }
        .navigationTitle("Motion")
        .onAppear {
            model.motion.startActivityUpdate()
            model.motion.startPedometer()
            model.motion.startAccelerometerUpdates()
        }
        .onDisappear {
            
        }
    }

}
