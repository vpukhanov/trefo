import SwiftUI

struct TravelModeView: View {
    var startTravelDate: Date
    var stopTravelMode: (Bool) async -> Void
    
    var body: some View {
        VStack {
            Text("Travel Mode On")
                .font(.title)
            
            Text("Since ") +
            Text(startTravelDate, style: .date)
            
            Button {
                Task {
                    await stopTravelMode(true)
                }
            } label: {
                Text("Turn Off and Move Photos to Album...")
            }
            .buttonStyle(.bordered)
            .foregroundColor(.accentColor)
            
            Button(role: .destructive) {
                Task {
                    await stopTravelMode(false)
                }
            } label: {
                Text("Leave Travel Mode")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
