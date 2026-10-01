// TrailMark CH10 watch — self-playing demo (mock data).
import SwiftUI

@MainActor
@Observable
final class WatchDirector {
    enum Screen: Hashable { case vitals, workout, memo, log }
    var path: [Screen] = []
    var showIntro = true
    var steps = 0.0
    var bpm = 0.0
    var kcal = 0.0
    var recording = false
    var recordSeconds = 0
    var minutes = 30
    var logState = 0 // 0 idle, 1 queued, 2 sent

    // Workout session (mirrors WorkoutSessionManager: isRunning, heartRate, activeEnergy, distanceMeters, elapsed)
    enum WorkoutPhase { case ready, countdown, running, summary }
    var workoutPhase = WorkoutPhase.ready
    var countdown = 3
    var elapsed: TimeInterval = 0
    var workoutBPM = 0.0
    var workoutKcal = 0.0
    var workoutMeters = 0.0
    var workoutSynced = false

    func sleep(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    func run() async {
        await sleep(2.2)
        withAnimation { showIntro = false }
        await sleep(0.5)
        withAnimation(.spring(duration: 1.4)) { steps = 8432 }
        await sleep(3.0)

        path = [.vitals]
        await sleep(0.6)
        let beats: [Double] = [118, 121, 124, 126, 128, 127, 129, 131, 128]
        for b in beats {
            withAnimation(.snappy) { bpm = b; kcal += 3 }
            await sleep(0.55)
        }
        kcal = 412
        await sleep(0.8)
        path = []
        await sleep(0.9)

        // Workout session
        path = [.workout]
        await sleep(1.4)
        withAnimation { workoutPhase = .countdown }
        for c in [3, 2, 1] { withAnimation(.snappy) { countdown = c }; await sleep(0.6) }
        withAnimation { workoutPhase = .running }
        // Fast-forward a 32-minute walk over ~6 seconds of video.
        for i in 1...30 {
            await sleep(0.2)
            withAnimation(.snappy) {
                elapsed = Double(i) * 64.5
                workoutBPM = 112 + 18 * sin(Double(i) / 6) + Double(i) / 3
                workoutKcal = Double(i) * 6.1
                workoutMeters = Double(i) * 87
            }
        }
        await sleep(0.8)
        withAnimation { workoutPhase = .summary }
        await sleep(1.6)
        withAnimation { workoutSynced = true }
        await sleep(2.0)
        path = []
        await sleep(0.9)

        path = [.memo]
        await sleep(0.8)
        withAnimation { recording = true }
        for s in 1...6 { await sleep(0.5); recordSeconds = s * 4 }
        withAnimation { recording = false }
        await sleep(1.4)
        path = []
        await sleep(0.9)

        path = [.log]
        await sleep(1.0)
        for _ in 0..<2 { await sleep(0.5); withAnimation { minutes += 5 } }
        await sleep(0.6)
        withAnimation { logState = 1 }
        await sleep(1.4)
        withAnimation { logState = 2 }
        await sleep(2.5)
    }
}

@main
struct TrailMarkWatchDemoApp: App {
    @State private var d = WatchDirector()
    var body: some Scene {
        WindowGroup {
            ContentView().environment(d).task { await d.run() }
        }
    }
}

struct ContentView: View {
    @Environment(WatchDirector.self) private var d
    var body: some View {
        @Bindable var d = d
        ZStack {
            NavigationStack(path: $d.path) {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Steps Today").font(.caption2).foregroundStyle(.secondary)
                            Text(d.steps.formatted(.number.precision(.fractionLength(0))))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                                .contentTransition(.numericText())
                            Text("6.24 km").font(.footnote).foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                    Section("iPhone Today") {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("8,432 steps").font(.headline)
                            Text("updated just now").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Label("Live Vitals", systemImage: "heart.fill")
                        Label("Workout", systemImage: "figure.hiking")
                        Label("Voice Memo", systemImage: "mic.fill")
                        Label("Quick Log", systemImage: "figure.walk")
                    }
                }
                .navigationTitle("TrailMark")
                .navigationDestination(for: WatchDirector.Screen.self) { screen in
                    switch screen {
                    case .vitals: VitalsView()
                    case .workout: WorkoutView()
                    case .memo: MemoView()
                    case .log: LogView()
                    }
                }
            }
            if d.showIntro {
                ZStack {
                    LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                    VStack(spacing: 6) {
                        Image(systemName: "figure.hiking").font(.system(size: 44, weight: .bold))
                        Text("TrailMark").font(.system(.title2, design: .rounded, weight: .heavy))
                        Text("on your wrist").font(.caption)
                    }
                    .foregroundStyle(.white)
                }
                .transition(.opacity)
            }
        }
    }
}

struct VitalsView: View {
    @Environment(WatchDirector.self) private var d
    var body: some View {
        List {
            row("Heart Rate", d.bpm > 0 ? "\(Int(d.bpm))" : "—", "bpm", "heart.fill", .red, pulse: true)
            row("Steps", d.steps.formatted(.number.precision(.fractionLength(0))), "", "figure.walk", .yellow)
            row("Active Energy", "\(Int(d.kcal))", "kcal", "flame.fill", .orange)
        }
        .navigationTitle("Live Vitals")
    }

    private func row(_ title: String, _ value: String, _ unit: String, _ symbol: String, _ tint: Color, pulse: Bool = false) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: pulse)
            VStack(alignment: .leading) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text(value).font(.system(.title3, design: .rounded, weight: .semibold)).contentTransition(.numericText())
                    if !unit.isEmpty { Text(unit).font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }
    }
}

struct MemoView: View {
    @Environment(WatchDirector.self) private var d
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(d.recording ? Color.red : Color.red.opacity(0.25)).frame(width: 74, height: 74)
                Image(systemName: d.recording ? "stop.fill" : "mic.fill").font(.title).foregroundStyle(.white)
            }
            .scaleEffect(d.recording ? 1.08 : 1)
            .animation(.easeInOut(duration: 0.5).repeat(while: d.recording), value: d.recording)
            Text(String(format: "0:%02d", d.recordSeconds)).font(.title3.monospacedDigit())
            Text(d.recording ? "Recording…" : (d.recordSeconds > 0 ? "Sending to iPhone ✓" : "Tap to record"))
                .font(.footnote).foregroundStyle(d.recording ? .red : .green)
        }
        .navigationTitle("Voice Memo")
    }
}

struct LogView: View {
    @Environment(WatchDirector.self) private var d
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "minus").foregroundStyle(.secondary)
                    Spacer()
                    Text("\(d.minutes) min").font(.title3.monospacedDigit()).contentTransition(.numericText())
                    Spacer()
                    Image(systemName: "plus").foregroundStyle(.orange)
                }
            } footer: { Text("≈ \(d.minutes * 80) m walk") }
            Section {
                if d.logState > 0 {
                    Label(d.logState == 1 ? "Queued for iPhone" : "Sent to iPhone",
                          systemImage: d.logState == 1 ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(d.logState == 1 ? Color.secondary : Color.green)
                }
                Label("Log", systemImage: "square.and.arrow.up")
            }
        }
        .navigationTitle("Quick Log")
    }
}

extension Animation {
    func `repeat`(while active: Bool) -> Animation { active ? repeatForever(autoreverses: true) : self }
}

// MARK: - Workout (live session UI for WorkoutSessionManager)

struct WorkoutView: View {
    @Environment(WatchDirector.self) private var d

    var body: some View {
        Group {
            switch d.workoutPhase {
            case .ready: ready
            case .countdown: countdownView
            case .running: running
            case .summary: summary
            }
        }
        .navigationTitle(d.workoutPhase == .running ? "" : "Workout")
    }

    private var ready: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(.green.opacity(0.2)).frame(width: 78, height: 78)
                Image(systemName: "figure.hiking").font(.system(size: 38, weight: .semibold)).foregroundStyle(.green)
            }
            Text("Outdoor Walk").font(.headline)
            Label("Start", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(.green, in: Capsule()).foregroundStyle(.black)
        }
        .padding(.horizontal)
    }

    private var countdownView: some View {
        ZStack {
            Circle().stroke(.green.opacity(0.25), lineWidth: 10)
            Circle().trim(from: 0, to: Double(d.countdown) / 3)
                .stroke(.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(d.countdown)").font(.system(size: 64, weight: .bold, design: .rounded))
                .contentTransition(.numericText(countsDown: true))
        }
        .padding(24)
    }

    private var running: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(timeText(d.elapsed))
                .font(.system(size: 38, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.yellow)
            metric("\(Int(d.workoutBPM))", "BPM", symbol: "heart.fill", tint: .red)
            metric("\(Int(d.workoutKcal))", "ACTIVE KCAL", symbol: "flame.fill", tint: .orange)
            metric((d.workoutMeters / 1000).formatted(.number.precision(.fractionLength(2))), "KM", symbol: "figure.hiking", tint: .green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private func metric(_ value: String, _ unit: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value).font(.system(.title2, design: .rounded, weight: .medium).monospacedDigit())
                .contentTransition(.numericText())
            Text(unit).font(.caption2.weight(.semibold)).foregroundStyle(tint)
            Spacer()
            Image(systemName: symbol).font(.caption).foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: symbol == "heart.fill")
        }
    }

    private var summary: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Outdoor Walk", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.headline)
                    Text(timeText(d.elapsed)).font(.title3.monospacedDigit()).foregroundStyle(.yellow)
                    Label(d.workoutSynced ? "Saved · Sent to iPhone" : "Saving…",
                          systemImage: d.workoutSynced ? "checkmark.icloud.fill" : "arrow.triangle.2.circlepath")
                        .font(.footnote).foregroundStyle(d.workoutSynced ? .green : .secondary)
                }
                .listRowBackground(Color.clear)
            }
            LabeledContent("Distance", value: "\((d.workoutMeters / 1000).formatted(.number.precision(.fractionLength(2)))) km")
            LabeledContent("Energy", value: "\(Int(d.workoutKcal)) kcal")
            LabeledContent("Avg HR", value: "124 bpm")
        }
    }

    private func timeText(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
    }
}
