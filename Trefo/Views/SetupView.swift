import SwiftUI

struct SetupView: View {
    var startTravelMode: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Travel Mode Off")
                .font(.title)
                .bold()
                .accessibilityAddTraits(.isHeader)

            Button {
                withAnimation {
                    startTravelMode()
                }
            } label: {
                Text("Turn On")
                    .padding(4)
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
