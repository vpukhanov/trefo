import SwiftUI

struct SetupView : View {
    var startTravelMode: () -> Void
    
    var body: some View {
        VStack {
            Text("Travel Mode Off")
                .font(.title)
            Button {
                withAnimation { startTravelMode() }
            } label: {
                Text("Turn On")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
