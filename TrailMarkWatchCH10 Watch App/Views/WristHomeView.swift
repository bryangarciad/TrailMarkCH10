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
    }
}
