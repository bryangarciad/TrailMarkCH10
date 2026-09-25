import SwiftUI

@main
struct TrailMarkWatchCH10_Watch_AppApp: App {
    @State private var model = WatchModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
