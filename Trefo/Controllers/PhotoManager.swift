import Foundation
import Photos

enum PhotoManagerError: Error {
    case limitedLibraryAccess
    case deniedLibraryAccess
    case unableToCreateAlbum
}

actor PhotoManager {
    static let shared = PhotoManager()

    // Stable, localized date-only formatter for album titles.
    private static let albumNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private init() {}

    // Public API: unchanged signature
    func separatePhotos(since startDate: Date, until endDate: Date) async throws {
        try Task.checkCancellation()
        try await assertAuthorization()

        // Create or fetch album
        guard let album = try await fetchOrCreateAlbum(for: startDate) else {
            throw PhotoManagerError.unableToCreateAlbum
        }

        try Task.checkCancellation()

        // Build fetch options for the date interval
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeAllBurstAssets = true

        // creationDate BETWEEN {lowerBound, upperBound} (inclusive)
        let fromPredicate = NSPredicate(format: "creationDate >= %@", startDate as NSDate)
        let toPredicate = NSPredicate(format: "creationDate <= %@", endDate as NSDate)
        fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fromPredicate, toPredicate])

        let photos = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        // If nothing to add, short-circuit
        if photos.count == 0 {
            return
        }

        try Task.checkCancellation()

        // Perform the album modification
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest(for: album)
            request?.addAssets(photos)
        }
    }

    nonisolated func makeAlbumName(for date: Date) -> String {
        PhotoManager.albumNameFormatter.string(from: date)
    }

    private func fetchOrCreateAlbum(for date: Date) async throws -> PHAssetCollection? {
        let title = makeAlbumName(for: date)

        // Try to find an existing album with the same title first (idempotent).
        if let existing = fetchAlbum(named: title) {
            return existing
        }

        // Not found — create it.
        guard let placeholder = try await createAlbum(withTitle: title) else {
            return nil
        }

        // Fetch the created album by identifier to return a concrete collection.
        let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
        return fetchResult.firstObject
    }

    private func fetchAlbum(named title: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "localizedTitle == %@", title)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOptions)
        return collections.firstObject
    }

    private func createAlbum(withTitle title: String) async throws -> PHObjectPlaceholder? {
        var placeholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            placeholder = request.placeholderForCreatedAssetCollection
        }
        return placeholder
    }

    private func assertAuthorization() async throws {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

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
}
