import Foundation
import Combine
import CoreLocation
import UserNotifications
import MapKit

@MainActor
final class TravelNotificationManager: NSObject, ObservableObject {
    // MARK: - Singleton
    static let shared = TravelNotificationManager()

    // MARK: - Published state for SwiftUI
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var locationAuthStatus: CLAuthorizationStatus
    @Published private(set) var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastKnownRegion: String?

    // MARK: - Private
    private let locationManager = CLLocationManager()

    private enum Keys {
        static let enabled = "travelNotif.enabled"
        static let lastRegion = "travelNotif.lastRegion"
    }

    // MARK: - Init
    private override init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        self.lastKnownRegion = UserDefaults.standard.string(forKey: Keys.lastRegion)
        self.locationAuthStatus = CLLocationManager().authorizationStatus

        super.init()

        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = true
        // Country-level accuracy is enough and battery friendly
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = kCLDistanceFilterNone

        Task { await refreshNotificationAuth() }

        // If user had the feature on previously, resume monitoring if authorized.
        if isEnabled { startMonitoringIfAuthorized() }
    }

    // MARK: - Public API (call from SwiftUI)

    /// Toggle the feature on/off from UI. When turning on, this will request the
    /// required permissions (Notifications + Location Always) if needed.
    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.enabled)

        if enabled {
            await ensurePermissions()
            startMonitoringIfAuthorized()
        } else {
            stopMonitoring()
        }
    }

    /// Call on app launch and when returning to foreground to keep state in sync.
    func syncAuthorizationState() async {
        locationAuthStatus = locationManager.authorizationStatus
        await refreshNotificationAuth()
        if isEnabled { startMonitoringIfAuthorized() }
    }

    // MARK: - Permission workflow

    /// Ensure we have permissions for notifications and background location.
    func ensurePermissions() async {
        await requestNotificationPermissionIfNeeded()
        await requestLocationPermissionIfNeeded()
    }

    private func requestNotificationPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        notificationAuthStatus = settings.authorizationStatus

        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                let category = UNNotificationCategory(
                    identifier: "TRAVEL_COUNTRY_CHANGE",
                    actions: [],
                    intentIdentifiers: [],
                    options: [.customDismissAction]
                )
                center.setNotificationCategories([category])
            }
            await refreshNotificationAuth()
        } catch {
            // You could log this if you have logging infra.
        }
    }

    private func requestLocationPermissionIfNeeded() async {
        let status = locationManager.authorizationStatus
        locationAuthStatus = status

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // We’ll escalate to Always after WhenInUse is granted via delegate.
        case .authorizedWhenInUse:
            // Required for SLC background delivery
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    private func refreshNotificationAuth() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAuthStatus = settings.authorizationStatus
    }

    // MARK: - Monitoring control

    private func startMonitoringIfAuthorized() {
        let status = locationManager.authorizationStatus
        locationAuthStatus = status

        guard isEnabled else { return }

        if status == .authorizedAlways {
            locationManager.startMonitoringSignificantLocationChanges()
            isMonitoring = true
        } else {
            // If we’re not properly authorized, don’t monitor.
            isMonitoring = false
        }
    }

    private func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
        isMonitoring = false
    }

    // MARK: - Handle new locations → detect country change → notify

    private func handleNewLocation(_ location: CLLocation) {
        Task {
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else { return }
                let items = try await request.mapItems
                guard let region = items.first?.addressRepresentations?.regionName else { return }

                if region != lastKnownRegion {
                    lastKnownRegion = region
                    UserDefaults.standard.set(region, forKey: Keys.lastRegion)
                    await postCountryChangedNotification(region: region)
                }
            } catch {
                // Geocoding can fail intermittently; we can ignore and wait for next SLC.
            }
        }
    }

    private func postCountryChangedNotification(region: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        notificationAuthStatus = settings.authorizationStatus

        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "Welcome to \(region)"
        content.body = "Open Trefo to start collecting your photos in travel mode."
        content.sound = .default
        content.categoryIdentifier = "TRAVEL_COUNTRY_CHANGE"

        // Fire immediately once per detected change.
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do { try await center.add(request) } catch { /* ignore */ }
    }
}

// MARK: - CLLocationManagerDelegate
extension TravelNotificationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.locationAuthStatus = status

            // Elevate to Always after WhenInUse is granted
            if status == .authorizedWhenInUse {
                manager.requestAlwaysAuthorization()
            }

            // Start/stop monitoring based on current state
            if self.isEnabled {
                if status == .authorizedAlways {
                    self.startMonitoringIfAuthorized()
                } else if status == .denied || status == .restricted {
                    self.stopMonitoring()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.handleNewLocation(latest)
        }
    }
}
