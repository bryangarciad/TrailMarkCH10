// TrailMark CH10 — self-playing demo (mock data, no HealthKit / WatchConnectivity).
// Mirrors the real app's screens so it can be screen-recorded in the simulator.
import SwiftUI
import MapKit
import Charts

// MARK: - Mock data

struct DemoJourney: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let date: String
    let km: Double
    let memos: Int
    let duration: String
    let kcal: Int
    let bpm: Int
    let route: [CLLocationCoordinate2D]
    var fromWatch = false

    static func == (a: DemoJourney, b: DemoJourney) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct DemoMemo: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let isVideo: Bool
    let duration: String
    var fromWatch = false
}

enum Mock {
    // A loop around Golden Gate Park, San Francisco.
    static let route: [CLLocationCoordinate2D] = [
        (37.7694, -122.4862), (37.7712, -122.4830), (37.7721, -122.4781), (37.7716, -122.4728),
        (37.7702, -122.4688), (37.7683, -122.4660), (37.7667, -122.4688), (37.7660, -122.4741),
        (37.7663, -122.4795), (37.7674, -122.4842), (37.7694, -122.4862),
    ].map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }

    static let journeys: [DemoJourney] = [
        DemoJourney(title: "Golden Gate Park Loop", date: "Oct 1, 2026 at 7:12 AM", km: 6.2, memos: 3,
                    duration: "01:04:37", kcal: 412, bpm: 128, route: route),
        DemoJourney(title: "Lands End Trail", date: "Sep 28, 2026 at 5:40 PM", km: 5.4, memos: 2,
                    duration: "00:58:02", kcal: 361, bpm: 121, route: route),
        DemoJourney(title: "Twin Peaks Sunrise", date: "Sep 25, 2026 at 6:05 AM", km: 3.8, memos: 1,
                    duration: "00:41:15", kcal: 298, bpm: 134, route: route),
        DemoJourney(title: "Watch activity", date: "Sep 23, 2026 at 12:30 PM", km: 2.4, memos: 0,
                    duration: "00:30:00", kcal: 180, bpm: 112, route: route),
    ]

    static let memos: [DemoMemo] = [
        DemoMemo(title: "Fog rolling over the lake", isVideo: true, duration: "00:42"),
        DemoMemo(title: "Bison paddock — trail note", isVideo: false, duration: "01:18"),
        DemoMemo(title: "Windmill viewpoint", isVideo: false, duration: "00:36"),
    ]

    static let watchWorkout = DemoJourney(title: "Outdoor Walk · Apple Watch", date: "Oct 1, 2026 at 5:30 PM", km: 2.61,
                                          memos: 1, duration: "00:32:15", kcal: 183, bpm: 124, route: route,
                                          fromWatch: true)

    static let watchMemo = DemoMemo(title: "Wrist memo — summit check-in", isVideo: false,
                                    duration: "00:24", fromWatch: true)

    static let energy: [(String, Double)] = [
        ("Thu", 310), ("Fri", 455), ("Sat", 620), ("Sun", 380), ("Mon", 298), ("Tue", 505), ("Wed", 412),
    ]
}

// MARK: - Demo driver

@MainActor
@Observable
final class Director {
    var showIntro = true
    var showOutro = false
    var tab = 0
    var journeyPath: [DemoJourney] = []
    var journalPath: [DemoMemo] = []
    var caption = ""
    var outroSubtitle = "Built with SwiftUI · HealthKit · MapKit · WatchConnectivity"

    // Animated values
    var steps = 0.0
    var km = 0.0
    var kcal = 0.0
    var memos = Mock.memos
    var journeys = Mock.journeys
    var journeySync: Double? = nil
    var syncProgress: Double? = nil
    var playing = false
    var playhead = 0.0
    var sleepMinutes = 0.0
    var chartReveal = 0.0

    func sleep(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    func say(_ text: String) { withAnimation(.easeInOut(duration: 0.35)) { caption = text } }

    func run() async {
        if ProcessInfo.processInfo.arguments.contains("-workoutFinale") { return await runWorkoutFinale() }
        await sleep(6.0)
        withAnimation(.easeInOut(duration: 0.6)) { showIntro = false }

        // Today
        say("Today — live steps, distance and energy from HealthKit")
        await sleep(0.6)
        withAnimation(.spring(duration: 1.6)) { steps = 8432; km = 6.24; kcal = 412 }
        await sleep(3.6)

        // Journeys
        withAnimation { tab = 1 }
        say("Journeys — every route you record, mapped")
        await sleep(2.6)
        journeyPath = [Mock.journeys[0]]
        say("Route, workout stats and memos captured along the way")
        await sleep(5.5)
        journeyPath = []
        await sleep(1.0)

        // Journal + watch sync
        withAnimation { tab = 2 }
        say("Field Journal — voice and video memos")
        await sleep(2.4)
        say("A memo recorded on Apple Watch syncs over…")
        withAnimation(.spring) { memos.insert(Mock.watchMemo, at: 0); syncProgress = 0 }
        for i in 1...20 {
            await sleep(0.11)
            withAnimation(.linear(duration: 0.1)) { syncProgress = Double(i) / 20 }
        }
        await sleep(0.4)
        withAnimation(.spring) { syncProgress = nil }
        say("…and you can see it land — Sync You Can See")
        await sleep(2.2)
        journalPath = [Mock.watchMemo]
        say("Tap to play back with a live waveform")
        await sleep(1.0)
        playing = true
        for i in 1...40 {
            await sleep(0.08)
            playhead = Double(i) / 40
        }
        playing = false
        await sleep(0.6)
        journalPath = []
        await sleep(0.9)

        // Recovery
        withAnimation { tab = 3 }
        say("Recovery — last night's sleep and a 7-day energy trend")
        await sleep(0.5)
        withAnimation(.spring(duration: 1.4)) { sleepMinutes = 444; chartReveal = 1 }
        await sleep(4.2)

        say("")
        outroSubtitle = "Next: a workout on Apple Watch  →"
        withAnimation(.easeInOut(duration: 0.6)) { showOutro = true }
    }
}

extension Director {
    /// Closing scene: the workout recorded on the watch arrives on the phone.
    func runWorkoutFinale() async {
        showIntro = false
        tab = 1
        await sleep(3.0)
        say("The walk you just recorded on Apple Watch…")
        withAnimation(.spring) { journeys.insert(Mock.watchWorkout, at: 0); journeySync = 0 }
        for i in 1...20 {
            await sleep(0.1)
            withAnimation(.linear(duration: 0.1)) { journeySync = Double(i) / 20 }
        }
        await sleep(0.3)
        withAnimation(.spring) { journeySync = nil }
        say("…lands in Journeys, workout and all")
        await sleep(2.2)
        journeyPath = [Mock.watchWorkout]
        say("Duration, energy and heart rate from the watch session")
        await sleep(5.0)
        say("")
        withAnimation(.easeInOut(duration: 0.6)) { showOutro = true }
    }
}

// MARK: - App

@main
struct TrailMarkDemoApp: App {
    @State private var director = Director()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(director)
                .task { await director.run() }
        }
    }
}

struct RootView: View {
    @Environment(Director.self) private var d
    var body: some View {
        @Bindable var d = d
        ZStack(alignment: .bottom) {
            TabView(selection: $d.tab) {
                Tab("Today", systemImage: "sun.max.fill", value: 0) { TodayView() }
                Tab("Journeys", systemImage: "map.fill", value: 1) { JourneysView() }
                Tab("Journal", systemImage: "waveform", value: 2) { JournalView() }
                Tab("Recovery", systemImage: "bed.double.fill", value: 3) { RecoveryView() }
            }
            .tint(.orange)

            if !d.caption.isEmpty {
                Text(d.caption)
                    .font(.callout.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.orange.opacity(0.5), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                    .id(d.caption)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if d.showIntro { TitleCard(subtitle: "Your trail. Your health. Phone + Watch.").transition(.opacity) }
            if d.showOutro { TitleCard(subtitle: d.outroSubtitle).transition(.opacity) }
        }
    }
}

struct TitleCard: View {
    let subtitle: String
    var body: some View {
        ZStack {
            LinearGradient(colors: [.orange, .red.opacity(0.85), .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "figure.hiking")
                    .font(.system(size: 84, weight: .bold))
                    .symbolEffect(.bounce, options: .repeating)
                Text("TrailMark").font(.system(size: 52, weight: .heavy, design: .rounded))
                Text(subtitle).font(.headline).multilineTextAlignment(.center).opacity(0.9)
                    .padding(.horizontal, 40)
            }
            .foregroundStyle(.white)
        }
    }
}

// MARK: - Today

struct TodayView: View {
    @Environment(Director.self) private var d
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MetricCard(title: "Steps", value: d.steps.formatted(.number.precision(.fractionLength(0))),
                               symbol: "figure.walk", tint: .orange)
                    MetricCard(title: "Distance", value: d.km.formatted(.number.precision(.fractionLength(2))) + " km",
                               symbol: "point.topleft.down.curvedto.point.bottomright.up", tint: .teal)
                    MetricCard(title: "Active Energy", value: d.kcal.formatted(.number.precision(.fractionLength(0))) + " kcal",
                               symbol: "flame.fill", tint: .red)
                    HStack {
                        Image(systemName: "applewatch.radiowaves.left.and.right").foregroundStyle(.green)
                        Text("Mirrored to Apple Watch").font(.footnote).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                .padding()
            }
            .navigationTitle("Today's Data")
        }
    }
}

struct MetricCard: View {
    let title: String, value: String, symbol: String, tint: Color
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.title).foregroundStyle(tint).frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Text(value).font(.system(.title, design: .rounded, weight: .bold)).contentTransition(.numericText())
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Journeys

struct JourneysView: View {
    @Environment(Director.self) private var d
    var body: some View {
        @Bindable var d = d
        NavigationStack(path: $d.journeyPath) {
            List(d.journeys) { j in
                NavigationLink(value: j) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(j.title).font(.headline)
                        HStack(spacing: 12) {
                            Label("\(j.km.formatted()) km", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                            Label("\(j.memos)", systemImage: "waveform")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        if j.fromWatch {
                            if let p = d.journeySync {
                                Label("Syncing workout \(Int(p * 100))%", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption).foregroundStyle(.orange)
                                ProgressView(value: p).tint(.orange)
                            } else {
                                Label("Workout from Apple Watch", systemImage: "applewatch")
                                    .font(.caption).foregroundStyle(.green)
                            }
                        }
                        Text(j.date).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("Journeys")
            .navigationDestination(for: DemoJourney.self) { JourneyDetail(journey: $0) }
            .toolbar { ToolbarItem(placement: .primaryAction) { Image(systemName: "plus.circle.fill") } }
        }
    }
}

struct JourneyDetail: View {
    let journey: DemoJourney
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 37.7690, longitude: -122.4760),
                    span: MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.03)))) {
                    MapPolyline(coordinates: journey.route).stroke(.orange, lineWidth: 5)
                    Marker("Video Memo", systemImage: "video.fill", coordinate: journey.route[2]).tint(.orange)
                    Marker("Voice Memo", systemImage: "waveform", coordinate: journey.route[5]).tint(.indigo)
                    Marker("Voice Memo", systemImage: "waveform", coordinate: journey.route[8]).tint(.indigo)
                }
                .frame(height: journey.fromWatch ? 200 : 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if journey.fromWatch {
                    Label("Recorded with Apple Watch · saved to Health", systemImage: "applewatch.radiowaves.left.and.right")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.green)
                }
                HStack {
                    stat("Distance", "\(journey.km.formatted()) km")
                    Divider()
                    stat("Memos", "\(journey.memos)")
                    Divider()
                    stat("Date", "Oct 1")
                }
                .frame(maxWidth: .infinity).padding()
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Label("Activity", systemImage: "figure.walk").font(.headline)
                    LabeledContent("Duration", value: journey.duration)
                    LabeledContent("Active Energy", value: "\(journey.kcal) kcal")
                    LabeledContent("Avg. Heart Rate", value: "\(journey.bpm) bpm")
                }
                .padding()
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle(journey.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Journal

struct JournalView: View {
    @Environment(Director.self) private var d
    var body: some View {
        @Bindable var d = d
        NavigationStack(path: $d.journalPath) {
            List(d.memos) { memo in
                NavigationLink(value: memo) { MemoRow(memo: memo) }
            }
            .navigationTitle("Field Journal")
            .navigationDestination(for: DemoMemo.self) { MemoDetail(memo: $0) }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Image(systemName: "video.badge.plus")
                    Image(systemName: "mic.badge.plus")
                }
            }
        }
    }
}

struct MemoRow: View {
    @Environment(Director.self) private var d
    let memo: DemoMemo
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(memo.isVideo
                          ? AnyShapeStyle(LinearGradient(colors: [.teal, .indigo], startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(.background.secondary))
                Image(systemName: memo.isVideo ? "video.fill" : "waveform")
                    .foregroundStyle(memo.isVideo ? .white : .secondary)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(memo.title).font(.headline).lineLimit(1)
                HStack(spacing: 8) {
                    Label(memo.duration, systemImage: "clock")
                    if memo.fromWatch {
                        if let p = d.syncProgress {
                            Label("Syncing \(Int(p * 100))%", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.orange)
                        } else {
                            Label("From Watch", systemImage: "applewatch").foregroundStyle(.green)
                        }
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                if memo.fromWatch, let p = d.syncProgress {
                    ProgressView(value: p).tint(.orange)
                }
            }
        }
    }
}

struct MemoDetail: View {
    @Environment(Director.self) private var d
    let memo: DemoMemo
    private let bars: [Double] = (0..<48).map { i in 0.25 + 0.75 * abs(sin(Double(i) * 0.55) * cos(Double(i) * 0.21)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 12) {
                    HStack(alignment: .center, spacing: 3) {
                        ForEach(bars.indices, id: \.self) { i in
                            Capsule()
                                .fill(Double(i) / Double(bars.count) <= d.playhead ? Color.orange : Color.secondary.opacity(0.35))
                                .frame(height: 88 * bars[i])
                        }
                    }
                    .frame(height: 88)
                    HStack {
                        Text("0:\(String(format: "%02d", Int(24 * d.playhead)))")
                        Spacer()
                        Text("-0:\(String(format: "%02d", 24 - Int(24 * d.playhead)))")
                    }
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Label(d.playing ? "Pause" : "Play", systemImage: d.playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2).foregroundStyle(.orange)
                }
                .padding(20)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text(memo.title).font(.title3.bold())
                    LabeledContent("Recorded on", value: "Apple Watch")
                    LabeledContent("Duration", value: memo.duration)
                    LabeledContent("Location", value: "37.7702° N, 122.4688° W")
                }
            }
            .padding()
        }
        .navigationTitle("Voice Memo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Recovery

struct RecoveryView: View {
    @Environment(Director.self) private var d
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Last night's sleep", systemImage: "bed.double.fill").font(.headline)
                        Text("\(Int(d.sleepMinutes) / 60) hr \(Int(d.sleepMinutes) % 60) min")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(.indigo)
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding()
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Active energy · last 7 days", systemImage: "flame.fill").font(.headline)
                        Chart(Mock.energy, id: \.0) { day in
                            BarMark(x: .value("Day", day.0), y: .value("kcal", day.1 * d.chartReveal))
                                .foregroundStyle(.red.gradient)
                                .cornerRadius(6)
                        }
                        .chartYScale(domain: 0...700)
                        .frame(height: 200)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding()
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("Recovery")
        }
    }
}
