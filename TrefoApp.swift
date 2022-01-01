import SwiftUI

@main
struct TrefoApp: App {
    @AppStorage("startTravelDate") var startTravelDate: Date?
    
    var body: some Scene {
        WindowGroup {
            ContentView(startTravelDate: $startTravelDate)
        }
    }
}
