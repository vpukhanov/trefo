import SwiftUI

struct TravelModeView: View {
    var startTravelDate: Date
    var stopTravelMode: (Bool) async -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack {
                Text("Travel Mode On")
                    .font(.title)
                    .bold()
                    .accessibilityAddTraits(.isHeader)
                
                Text("Since \(startTravelDate, style: .date)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    await stopTravelMode(true)
                }
            } label: {
                Text("Turn Off and Move Photos to Album…")
                    .padding(4)
            }
            .buttonStyle(.glassProminent)
            .tint(.accentColor)
            .accessibilityLabel("Turn off Travel Mode and move photos to an album")

            Button(role: .destructive) {
                Task {
                    await stopTravelMode(false)
                }
            } label: {
                Text("Leave Travel Mode")
                    .padding(4)
            }
            .buttonStyle(.glassProminent)
            .accessibilityLabel("Leave Travel Mode without moving photos")
        }
    }
}

#Preview {
    TravelModeView(startTravelDate: .now) { _ in }
}
