import SwiftUI
import TrailMarkCH10Core

struct LiveVitalsView: View  {
    @Environment(WatchModel.self) private var model
    
    var liveVitals: LiveVitals {
        model.health.liveVitals
    }
    
    var body: some View {
        List {
            vitalCard(
                title: "Heart Rate",
                value: liveVitals.heartRateText,
                unit: "bpm",
                symbol: "heart.fill",
                tint: .red
            )
            vitalCard(
                title: "Steps",
                value: "\(Int(liveVitals.steps))",
                unit: "",
                symbol: "figure.walking",
                tint: .yellow
            )
            vitalCard(
                title: "Active Energy",
                value: "\(Int(liveVitals.activeEnergyKcal))",
                unit: "kCal",
                symbol: "flame.fill",
                tint: .orange
            )
        }
        .navigationTitle("Live Vitals")
        .task {
            await model.health.requestAuthorization()
            model.health.startLiveHeartUpdates()
        }
        .onDisappear { model.health.stopLiveQueries() } // This will do fine if the user explicitely navigates back or exit
    }
    
    private func vitalCard(title: String, value: String, unit: String, symbol: String, tint: Color) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(tint)
            VStack(alignment: .leading) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                HStack {
                    Text(value).font(.system(.title3, design: .rounded, weight: .semibold))
                    if !unit.isEmpty {
                        Text(unit).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

