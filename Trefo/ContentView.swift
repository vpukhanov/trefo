//
//  ContentView.swift
//  Trefo
//
//  Created by Вячеслав Пуханов on 04.11.2025.
//

import SwiftUI

private enum ActiveAlert: Identifiable, Equatable {
    case leaveConfirm
    case permissionsError
    case success(date: Date)
    case generic(message: String)

    var id: String {
        switch self {
        case .leaveConfirm: return "leaveConfirm"
        case .permissionsError: return "permissionsError"
        case .success(let date): return "success-\(date.timeIntervalSince1970)"
        case .generic(let message): return "generic-\(message)"
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
                
                if let startTravelDate {
                    TravelModeView(
                        startTravelDate: startTravelDate,
                        stopTravelMode: stopTravelMode
                    )
                } else {
                    SetupView(startTravelMode: startTravelMode)
                }
            }
            .toolbar {
                Button {
                    withAnimation { isPresentingSettings = true }
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .foregroundColor(.white)
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .leaveConfirm:
                    return Alert(
                        title: Text("Leave Travel Mode"),
                        message: Text("Leaving travel mode will leave the photos as is, without sorting them into albums."),
                        primaryButton: .cancel(Text("Cancel")),
                        secondaryButton: .destructive(Text("Leave"), action: {
                            withAnimation { cancelTravelMode() }
                        })
                    )
                    
                case .permissionsError:
                    return Alert(
                        title: Text("No Photo Library Permissions"),
                        message: Text("Trefo needs full photo library access to move your travel photos to a separate album."),
                        primaryButton: .cancel(Text("Cancel")),
                        secondaryButton: .default(Text("Go to Settings"), action: {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                openURL(settingsURL)
                            }
                        })
                    )
                    
                case .success(let date):
                    return Alert(
                        title: Text("Left Travel Mode"),
                        message: Text("Successfully created a new album \"\(PhotoManager.shared.makeAlbumName(for: date))\" and moved all photos taken during travel mode into it."),
                        dismissButton: .default(Text("OK"), action: {
                            cancelTravelMode()
                        })
                    )
                    
                case .generic(let message):
                    return Alert(
                        title: Text("Error"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsView()
            }
        }
    }

    private var background: some View {
        Image(startTravelDate == nil ? "SetupBackground" : "TravelModeBackground")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .brightness(-0.5)
            .animation(nil, value: startTravelDate)
            .accessibilityHidden(true)
    }

    private func startTravelMode() {
        startTravelDate = Date()
    }

    @MainActor
    private func stopTravelMode(movePhotos: Bool) async {
        if let startDate = startTravelDate, movePhotos {
            do {
                try await PhotoManager.shared.separatePhotos(since: startDate, until: Date())
                activeAlert = .success(date: startDate)
            } catch PhotoManagerError.limitedLibraryAccess, PhotoManagerError.deniedLibraryAccess {
                activeAlert = .permissionsError
            } catch {
                // Avoid crashing; surface a generic error instead.
                activeAlert = .generic(message: "An unexpected error occurred: \(error.localizedDescription)")
            }
        } else {
            activeAlert = .leaveConfirm
        }
    }

    private func cancelTravelMode() {
        startTravelDate = nil
    }
}

#Preview {
    ContentView()
}
