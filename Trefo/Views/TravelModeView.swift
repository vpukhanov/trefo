import SwiftUI

struct TravelModeView: View {
    var startTravelDate: Date
    var stopTravelMode: (Bool) async -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack {
                Text("Travel Mode is On")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)

                Text("Since \(startTravelDate, format: .dateTime.year().month().day())")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    await stopTravelMode(true)
                }
            } label: {
                Label("Turn Off and Create an Album", systemImage: "folder.fill.badge.plus")
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .accessibilityLabel("Turn off Travel Mode and move photos to an album")

            Button(role: .destructive) {
                Task {
                    await stopTravelMode(false)
                }
            } label: {
                Label("Leave Travel Mode", systemImage: "xmark.circle")
            }
            .buttonStyle(.glassProminent)
            .accessibilityLabel("Leave Travel Mode without moving photos")
        }
    }
}

#Preview {
    TravelModeView(startTravelDate: .now) { _ in }
}
