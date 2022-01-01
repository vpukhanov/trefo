import Foundation
import Photos

enum PhotoManagerError: Error {
    case limitedLibraryAccess
    case deniedLibraryAccess
    case unableToCreateAlbum
}

class PhotoManager {
    static let shared = PhotoManager()
    
    private static let albumNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private init() {}
    
    func separatePhotos(since startDate: Date, until endDate: Date) async throws {
        try await assertAuthorization()
        
        guard let albumPlaceholder = try await createAlbum(for: startDate) else {
            throw PhotoManagerError.unableToCreateAlbum
        }
        guard let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumPlaceholder.localIdentifier], options: nil).firstObject else {
            throw PhotoManagerError.unableToCreateAlbum
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "creationDate >= %@ && creationDate <= %@", startDate as NSDate, endDate as NSDate)
        fetchOptions.includeAllBurstAssets = true
        
        let photos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest(for: album)
            request?.addAssets(photos)
        }
    }
    
    func makeAlbumName(for date: Date) -> String {
        PhotoManager.albumNameFormatter.string(from: date)
    }
    
    private func createAlbum(for date: Date) async throws -> PHObjectPlaceholder? {
        var albumPlaceholder: PHObjectPlaceholder?
        
        let title = makeAlbumName(for: date)
        try await PHPhotoLibrary.shared().performChanges {
            let album = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            albumPlaceholder = album.placeholderForCreatedAssetCollection
        }
        
        return albumPlaceholder
    }
    
    private func assertAuthorization() async throws {
        var authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if authStatus == .notDetermined {
            authStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        
        if authStatus == .limited {
            throw PhotoManagerError.limitedLibraryAccess
        }
        
        if authStatus == .restricted || authStatus == .denied {
            throw PhotoManagerError.deniedLibraryAccess
        }
    }
}
