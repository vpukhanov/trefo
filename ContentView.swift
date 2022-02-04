import SwiftUI

struct ContentView: View {
    @Binding var startTravelDate: Date?
    
    @State private var showingCancelConfirmation = false
    @State private var showingPhotoLibraryPermissionsError = false
    @State private var showingSuccessConfirmation = false
    
    var body: some View {
        ZStack {
            background
            
            if let startTravelDate = startTravelDate {
                TravelModeView(
                    startTravelDate: startTravelDate,
                    stopTravelMode: stopTravelMode
                )
            } else {
                SetupView(startTravelMode: startTravelMode)
            }
        }
        .foregroundColor(.white)
        .alert(
            "Leave Travel Mode",
            isPresented: $showingCancelConfirmation,
            actions: {
                Button("Cancel", role: .cancel) {}
                Button("Leave") {
                    withAnimation { cancelTravelMode() }
                }
            },
            message: {
                Text("Leaving travel mode will leave the photos as is, without sorting them into albums.")
            }
        )
        .alert(
            "No Photo Library Permissions",
            isPresented: $showingPhotoLibraryPermissionsError,
            actions: {
                Button("Cancel", role: .cancel) {}
                Button("Go to Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
            },
            message: {
                Text("Trefo needs full photo library access to move your travel photos to a separate album.")
            }
        )
        .alert(
            "Left Travel Mode",
            isPresented: $showingSuccessConfirmation,
            presenting: startTravelDate,
            actions: { _ in
                Button("OK") {
                    cancelTravelMode()
                }
            },
            message: { date in
                Text("Successfully created a new album \"\(PhotoManager.shared.makeAlbumName(for: date))\" and moved all photos taken during travel mode into it.")
            }
        )
    }
    
    private var background: some View {
        Image(startTravelDate == nil ? "SetupBackground" : "TravelModeBackground")
            .resizable()
            .scaledToFill()
            .edgesIgnoringSafeArea(.all)
            .brightness(-0.5)
            .animation(nil, value: startTravelDate)
    }
    
    private func startTravelMode() {
        startTravelDate = Date()
    }
    
    private func stopTravelMode(movePhotos: Bool) async {
        if let startDate = startTravelDate, movePhotos {
            do {
                try await PhotoManager.shared.separatePhotos(since: startDate, until: Date())
                showingSuccessConfirmation = true
            } catch PhotoManagerError.limitedLibraryAccess, PhotoManagerError.deniedLibraryAccess {
                showingPhotoLibraryPermissionsError = true
            } catch {
                fatalError("Unknown stop travel mode error: \(error)")
            }
        } else {
            showingCancelConfirmation = true
        }
    }
    
    private func cancelTravelMode() {
        startTravelDate = nil
    }
}
