import Foundation
import Photos

// MARK: - Errors

enum PhotoManagerError: LocalizedError {
    case limitedLibraryAccess
    case deniedLibraryAccess
    case unableToCreateAlbum

    var errorDescription: String? {
        switch self {
        case .limitedLibraryAccess:
            "Access is limited to a subset of your photo library. Full access is required."
        case .deniedLibraryAccess:
            "Photo library access is denied. Please enable it in Settings."
        case .unableToCreateAlbum:
            "Unable to create or fetch the album for this trip."
        }
    }
}

// MARK: - Actor

actor PhotoManager {
    static let shared = PhotoManager()

    /// Localized, date-based album title format.
    private static let albumTitleFormat = Date.FormatStyle()
        .year()
        .month(.abbreviated)
        .day()

    private init() {}

    // MARK: Public API

    /// Returns the current authorization status for `.readWrite`.
    func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Ensures the app has full `.authorized` access to the photo library.
    /// Requests access if the status is `.notDetermined`.
    func ensureAuthorization() async throws {
        var status = authorizationStatus()

        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }

        switch status {
        case .authorized:
            return
        case .limited:
            throw PhotoManagerError.limitedLibraryAccess
        case .denied, .restricted:
            throw PhotoManagerError.deniedLibraryAccess
        default:
            throw PhotoManagerError.deniedLibraryAccess
        }
    }

    /// Creates or reuses a date-named album and adds all images created
    /// within the specified date interval to that album.
    ///
    /// - Returns: The album that contains (or now contains) the trip photos.
    @discardableResult
    func separateTripPhotos(from startDate: Date, to endDate: Date) async throws -> PHAssetCollection {
        try Task.checkCancellation()
        try await ensureAuthorization()

        let (lowerBound, upperBound) = ordered(startDate, endDate)

        let album = try await fetchOrCreateAlbum(forTripStarting: lowerBound)

        try Task.checkCancellation()

        // Fetch images in the given date interval.
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeAllBurstAssets = true

        let fromPredicate = NSPredicate(format: "creationDate >= %@", lowerBound as NSDate)
        let toPredicate = NSPredicate(format: "creationDate <= %@", upperBound as NSDate)
        fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fromPredicate, toPredicate])

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        // Nothing to add, but we still return the album.
        guard assets.count > 0 else {
            return album
        }

        try Task.checkCancellation()

        try await PHPhotoLibrary.shared().performChanges {
            guard let changeRequest = PHAssetCollectionChangeRequest(for: album) else { return }
            changeRequest.addAssets(assets)
        }

        return album
    }

    /// Convenience to generate the album title used for a given trip start date.
    nonisolated func albumTitle(for tripStartDate: Date) -> String {
        tripStartDate.formatted(Self.albumTitleFormat)
    }

    // MARK: Private helpers

    private func fetchOrCreateAlbum(forTripStarting startDate: Date) async throws -> PHAssetCollection {
        let title = albumTitle(for: startDate)

        if let existing = fetchAlbum(withTitle: title) {
            return existing
        }

        guard let placeholder = try await createAlbum(title: title) else {
            throw PhotoManagerError.unableToCreateAlbum
        }

        let result = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [placeholder.localIdentifier],
            options: nil
        )

        guard let collection = result.firstObject else {
            throw PhotoManagerError.unableToCreateAlbum
        }

        return collection
    }

    private func fetchAlbum(withTitle title: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "localizedTitle == %@", title)

        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: options
        )

        return collections.firstObject
    }

    private func createAlbum(title: String) async throws -> PHObjectPlaceholder? {
        var placeholder: PHObjectPlaceholder?

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            placeholder = request.placeholderForCreatedAssetCollection
        }

        return placeholder
    }

    private func ordered(_ a: Date, _ b: Date) -> (Date, Date) {
        if a <= b { return (a, b) }
        return (b, a)
    }
}
