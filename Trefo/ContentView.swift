import SwiftUI
import CoreLocation
import UserNotifications
import UIKit

private enum ActiveAlert: Identifiable, Equatable {
    case leaveConfirm
    case permissionsError
    case success(date: Date)
    case generic(message: String)

    var id: String {
        switch self {
        case .leaveConfirm:
            "leaveConfirm"
        case .permissionsError:
            "permissionsError"
        case .success(let date):
            "success-\(date.timeIntervalSince1970)"
        case .generic(let message):
            "generic-\(message)"
        }
    }
}

struct ContentView: View {
    @AppStorage("startTravelDate") private var startTravelDate: Date?

    @State private var activeAlert: ActiveAlert?
    @State private var isPresentingSettings = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                background

                Group {
                    if let startTravelDate {
                        TravelModeView(
                            startTravelDate: startTravelDate,
                            stopTravelMode: stopTravelMode
                        )
                    } else {
                        SetupView(startTravelMode: startTravelMode)
                    }
                }
                .padding()
                .multilineTextAlignment(.center)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            isPresentingSettings = true
                        }
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .foregroundStyle(.white)
            .alert(item: $activeAlert, content: alert(for:))
            .sheet(isPresented: $isPresentingSettings) {
                SettingsView()
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        Image(startTravelDate == nil ? "SetupBackground" : "TravelModeBackground")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .brightness(-0.5)
            .overlay(.ultraThinMaterial)
            .accessibilityHidden(true)
    }

    // MARK: - Actions

    private func startTravelMode() {
        startTravelDate = Date()
    }

    @MainActor
    private func stopTravelMode(movePhotos: Bool) async {
        guard let startDate = startTravelDate else {
            activeAlert = .leaveConfirm
            return
        }

        if movePhotos {
            do {
                try await PhotoManager.shared.separateTripPhotos(from: startDate, to: Date())
                activeAlert = .success(date: startDate)
            } catch PhotoManagerError.limitedLibraryAccess,
                    PhotoManagerError.deniedLibraryAccess {
                activeAlert = .permissionsError
            } catch {
                activeAlert = .generic(
                    message: "An unexpected error occurred: \(error.localizedDescription)"
                )
            }
        } else {
            activeAlert = .leaveConfirm
        }
    }

    private func cancelTravelMode() {
        startTravelDate = nil
    }

    // MARK: - Alerts

    private func alert(for alert: ActiveAlert) -> Alert {
        switch alert {
        case .leaveConfirm:
            return Alert(
                title: Text("Leave Travel Mode"),
                message: Text("Leaving travel mode will leave the photos as is, without sorting them into albums."),
                primaryButton: .cancel(Text("Cancel")),
                secondaryButton: .destructive(Text("Leave")) {
                    withAnimation {
                        cancelTravelMode()
                    }
                }
            )

        case .permissionsError:
            return Alert(
                title: Text("No Photo Library Permissions"),
                message: Text("Trefo needs full photo library access to move your travel photos to a separate album."),
                primaryButton: .cancel(Text("Cancel")),
                secondaryButton: .default(Text("Open System Settings")) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        openURL(settingsURL)
                    }
                }
            )

        case .success(let date):
            let albumTitle = PhotoManager.shared.albumTitle(for: date)
            return Alert(
                title: Text("Travel Mode Finished"),
                message: Text("Created a new album “\(albumTitle)” and moved all photos taken during travel mode into it."),
                dismissButton: .default(Text("OK")) {
                    cancelTravelMode()
                }
            )

        case .generic(let message):
            return Alert(
                title: Text("Error"),
                message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    ContentView()
}
