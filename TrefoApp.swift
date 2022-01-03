import SwiftUI
import TelemetryClient

@main
struct TrefoApp: App {
    @AppStorage("startTravelDate") var startTravelDate: Date?
    
    init() {
        let configuration = TelemetryManagerConfiguration(appID: "078A2869-331F-49AD-953C-5EF45BF9038C")
        TelemetryManager.initialize(with: configuration)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(startTravelDate: $startTravelDate)
        }
    }
}
