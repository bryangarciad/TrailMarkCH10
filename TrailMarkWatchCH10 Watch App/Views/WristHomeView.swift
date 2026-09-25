import SwiftUI
import TrailMarkCH10Core

struct WristHomeView: View {
    @Environment(WatchModel.self) private var model
    
    private var summary: ActivitySummary {
        model.health.todaysSummary
    }
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                Text("Step Today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(summary.stepsText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
                Text(summary.distanceText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowBackground(Color.clear)
        }

        // Latest state mirrored from the phone over applicationContext.
        Section("iPhone Today") {
            if let mirrored = model.connectivity.mirroredSummary {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(mirrored.stepsText) steps")
                        .font(.headline)
                    Text(mirrored.distanceText)
                        .font(.footnote)
                    Text("updated \(Text(mirrored.date, style: .relative)) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Open TrailMark on your iPhone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
