//
//  SettingsView.swift
//  Trefo
//
//  Created by Вячеслав Пуханов on 04.11.2025.
//

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
        NavigationView {
            Form {
                // MARK: Travel notifications toggle + state
                Section(header: Text("Travel Notifications"), footer: Text("Get a reminder to turn on Travel Mode when you arrive in a new country.")) {
                    Toggle(isOn: enabledBinding) {
                        Text("Notifications")
                    }
                    
                    if let region = manager.lastKnownRegion {
                        HStack {
                            Label("Last region", systemImage: "globe")
                            Spacer()
                            Text(region)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .allowsTightening(true)
                        }
                    }
                }
                
                
                // MARK: Permission statuses
                if manager.isEnabled {
                    Section(header: Text("Permissions"),
                            footer: Text("For background country detection, Location should be “Always” and Notifications should be “Authorized“.")) {
                        HStack {
                            Label("Location", systemImage: "location.fill")
                            Spacer()
                            Text(locationDescription(manager.locationAuthStatus))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Label("Notifications", systemImage: "bell.fill")
                            Spacer()
                            Text(notificationDescription(manager.notificationAuthStatus))
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        } label: {
                            Label("Go to Settings…", systemImage: "gearshape")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                await manager.syncAuthorizationState()
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    Task { await manager.syncAuthorizationState() }
                }
            }
            .toolbar {
                Button(role: .close) {
                    dismiss()
                } label: {
                    Text("Done")
                }
            }
        }
    }

    // MARK: - Bindings & helpers

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { manager.isEnabled },
            set: { newValue in
                Task { await manager.setEnabled(newValue) }
            }
        )
    }

    private func locationDescription(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways:     return "Always"
        case .authorizedWhenInUse:  return "When In Use"
        case .denied:               return "Denied"
        case .restricted:           return "Restricted"
        case .notDetermined:        return "Not Determined"
        @unknown default:           return "Unknown"
        }
    }

    private func notificationDescription(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional:   return "Authorized"
        case .denied:       return "Denied"
        default:   return "Unknown"
        }
    }
}

#Preview {
    SettingsView()
}
