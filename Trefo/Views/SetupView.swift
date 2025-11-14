import SwiftUI

struct SetupView: View {
    var startTravelMode: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Travel Mode is Off")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Turn it on to automatically group photos from your next trip into a separate album.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 100)

            Button("Turn On Travel Mode", systemImage: "airplane.departure") {
                withAnimation(.easeInOut) {
                    startTravelMode()
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .accessibilityLabel("Turn on Travel Mode")
        }
    }
}

#Preview {
    SetupView(startTravelMode: {})
}
