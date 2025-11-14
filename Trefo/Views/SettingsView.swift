import SwiftUI
import CoreLocation
import UserNotifications
import UIKit

struct SettingsView: View {
    @StateObject private var manager = TravelNotificationManager.shared

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                travelNotificationsSection

                if manager.isEnabled {
                    permissionsSection
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .task {
                await manager.configureOnLaunch()
            }
            .onChange(of: scenePhase, initial: false) { _, newPhase in
                if newPhase == .active {
                    Task { await manager.configureOnLaunch() }
                }
            }
        }
    }

    // MARK: - Sections

    private var travelNotificationsSection: some View {
        Section {
            Toggle("Travel notifications", isOn: enabledBinding)

            if let region = manager.lastKnownRegion {
                LabeledContent {
                    Text(region)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } label: {
                    Label("Last region", systemImage: "globe")
                }
            }
        } footer: {
            Text("Get a reminder to turn on Travel Mode when you arrive in a new country")
        }
    }

    private var permissionsSection: some View {
        Section {
            LabeledContent {
                Text(locationDescription(manager.locationAuthorization))
                    .foregroundStyle(.secondary)
            } label: {
                Label("Location", systemImage: "location.fill")
            }

            LabeledContent {
                Text(notificationDescription(manager.notificationAuthorization))
                    .foregroundStyle(.secondary)
            } label: {
                Label("Notifications", systemImage: "bell.fill")
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Label("Open System Settings", systemImage: "gear")
            }
        } footer: {
            Text("For background country detection, Location should be “Always” and Notifications should be “Authorized”")
        }
    }

    // MARK: - Bindings

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { manager.isEnabled },
            set: { newValue in
                Task { await manager.setEnabled(newValue) }
            }
        )
    }

    // MARK: - Helpers

    private func locationDescription(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways:     "Always"
        case .authorizedWhenInUse:  "When In Use"
        case .denied:               "Denied"
        case .restricted:           "Restricted"
        case .notDetermined:        "Not Determined"
        @unknown default:           "Unknown"
        }
    }

    private func notificationDescription(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional: "Authorized"
        case .denied:                   "Denied"
        case .notDetermined:            "Not Determined"
        default:                        "Unknown"
        }
    }
}

#Preview {
    SettingsView()
}
