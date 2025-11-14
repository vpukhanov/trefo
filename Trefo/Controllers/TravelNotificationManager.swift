import Foundation
import Combine
import CoreLocation
import UserNotifications
import MapKit

/// Central coordinator for the “travel notifications” feature.
/// - Stores a user-facing toggle (enabled/disabled).
/// - Manages notification + background location permissions.
/// - Monitors significant location changes when allowed.
/// - Reverse-geocodes locations to a coarse region (e.g. country).
/// - Posts a local notification when the region changes.
@MainActor
final class TravelNotificationManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = TravelNotificationManager()

    // MARK: - Published state for SwiftUI

    /// User-facing toggle for the feature.
    @Published private(set) var isEnabled: Bool

    /// Whether we are currently monitoring significant location changes.
    @Published private(set) var isMonitoring: Bool = false

    /// Current location authorization status.
    @Published private(set) var locationAuthorization: CLAuthorizationStatus

    /// Current notification authorization status.
    @Published private(set) var notificationAuthorization: UNAuthorizationStatus = .notDetermined

    /// Last known (coarse) region name, e.g. “Finland”.
    @Published private(set) var lastKnownRegion: String?

    // MARK: - Private

    private let locationManager = CLLocationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults: UserDefaults

    private enum DefaultsKey {
        static let enabled = "travelNotifications.enabled"
        static let lastRegion = "travelNotifications.lastRegion"
    }

    private enum NotificationCategory {
        static let travelCountryChange = "TRAVEL_COUNTRY_CHANGE"
    }

    // MARK: - Init

    private override init() {
        self.userDefaults = .standard
        self.isEnabled = userDefaults.bool(forKey: DefaultsKey.enabled)
        self.lastKnownRegion = userDefaults.string(forKey: DefaultsKey.lastRegion)

        // Use a temporary manager to grab initial status without touching delegate yet.
        self.locationAuthorization = CLLocationManager().authorizationStatus

        super.init()

        // Configure location manager
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = kCLDistanceFilterNone

        Task {
            await refreshNotificationAuthorization()
        }
    }

    // MARK: - Public API (SwiftUI-friendly)

    /// Call from app launch / foreground to sync state and resume monitoring if appropriate.
    func configureOnLaunch() async {
        // Refresh statuses
        locationAuthorization = locationManager.authorizationStatus
        await refreshNotificationAuthorization()

        if isEnabled {
            startMonitoringIfAuthorized()
        } else {
            stopMonitoring()
        }
    }

    /// Toggle the travel notifications feature from UI.
    /// When enabling, will request required permissions and start monitoring if granted.
    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled else { return }

        isEnabled = enabled
        userDefaults.set(enabled, forKey: DefaultsKey.enabled)

        if enabled {
            await ensurePermissions()
            startMonitoringIfAuthorized()
        } else {
            stopMonitoring()
        }
    }

    /// Explicitly refresh permission states (useful if user changed them in Settings).
    func refreshPermissions() async {
        locationAuthorization = locationManager.authorizationStatus
        await refreshNotificationAuthorization()
        if isEnabled {
            startMonitoringIfAuthorized()
        } else {
            stopMonitoring()
        }
    }

    /// Convenience for SwiftUI: returns whether we *could* monitor given current permissions.
    var canMonitorInBackground: Bool {
        isEnabled && locationAuthorization == .authorizedAlways
    }

    // MARK: - Permissions

    /// Ensure we have notification + background location permissions.
    /// This function is “best effort” and does not throw; it updates state instead.
    func ensurePermissions() async {
        await requestNotificationPermissionIfNeeded()
        await requestLocationPermissionIfNeeded()
    }

    private func requestNotificationPermissionIfNeeded() async {
        let settings = await notificationCenter.notificationSettings()
        notificationAuthorization = settings.authorizationStatus

        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                registerNotificationCategories()
            }
            await refreshNotificationAuthorization()
        } catch {
            // You might log this error if you have logging infrastructure.
        }
    }

    private func registerNotificationCategories() {
        let travelCategory = UNNotificationCategory(
            identifier: NotificationCategory.travelCountryChange,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        notificationCenter.setNotificationCategories([travelCategory])
    }

    private func requestLocationPermissionIfNeeded() async {
        let status = locationManager.authorizationStatus
        locationAuthorization = status

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // Elevate to Always once WhenInUse is granted (handled in delegate).
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    private func refreshNotificationAuthorization() async {
        let settings = await notificationCenter.notificationSettings()
        notificationAuthorization = settings.authorizationStatus
    }

    // MARK: - Monitoring control

    private func startMonitoringIfAuthorized() {
        let status = locationManager.authorizationStatus
        locationAuthorization = status

        guard isEnabled else {
            isMonitoring = false
            return
        }

        if status == .authorizedAlways {
            locationManager.startMonitoringSignificantLocationChanges()
            isMonitoring = true
        } else {
            isMonitoring = false
        }
    }

    private func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
        isMonitoring = false
    }

    // MARK: - Location handling

    private func handleNewLocation(_ location: CLLocation) {
        Task { [weak self] in
            guard let self else { return }

            do {
                guard let request = MKReverseGeocodingRequest(location: location) else { return }
                let items = try await request.mapItems

                guard let item = items.first else { return }

                let regionName = item.addressRepresentations?.regionName

                guard let region = regionName, !region.isEmpty else { return }

                if region != self.lastKnownRegion {
                    await self.didChangeRegion(to: region)
                }
            } catch {
                // Reverse geocoding can fail sporadically; we simply wait for the next update.
            }
        }
    }

    private func didChangeRegion(to region: String) async {
        lastKnownRegion = region
        userDefaults.set(region, forKey: DefaultsKey.lastRegion)
        await postCountryChangedNotification(region: region)
    }

    private func postCountryChangedNotification(region: String) async {
        let settings = await notificationCenter.notificationSettings()
        notificationAuthorization = settings.authorizationStatus

        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Welcome to \(region)"
        content.body = "Open Trefo to start collecting your photos in travel mode."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.travelCountryChange

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // fire immediately
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            // Ignore; user will simply not see a notification in this case.
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension TravelNotificationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let status = manager.authorizationStatus
            self.locationAuthorization = status

            // Elevate to Always once WhenInUse is granted.
            if status == .authorizedWhenInUse {
                manager.requestAlwaysAuthorization()
            }

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

        Task { @MainActor [weak self] in
            self?.handleNewLocation(latest)
        }
    }
}
