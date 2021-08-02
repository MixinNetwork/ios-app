import MixinServices

class StickersStoreManager {

    static let shared = StickersStoreManager()
    
    private var ablumIds: [String] {
        return AppGroupUserDefaults.User.stickerAblums
    }
    
}

extension StickersStoreManager {
    
    func handleStickerOperation(with stickerStoreItem: StickerStoreItem) {
        if stickerStoreItem.isAdded {
            remove(album: stickerStoreItem.album)
        } else {
            add(album: stickerStoreItem.album)
        }
    }
    
    func add(album: Album) {
        AppGroupUserDefaults.User.stickerAblums = Array(Set(ablumIds + [album.albumId]))
        AlbumDAO.shared.insertOrUpdateAblum(album: album)
    }
    
    func remove(album: Album) {
        AppGroupUserDefaults.User.stickerAblums = ablumIds.filter({ $0 != album.albumId })
        AlbumDAO.shared.deleteAlbum(albumId: album.albumId)
    }
    
    func updateStickerAlbumSequence(albumIds: [String]) {
        AppGroupUserDefaults.User.stickerAblums = albumIds
    }
    
    // TODO: fetch from server and merge with local official
    func fetchMyStickers(completion: (([StickerStoreItem]) -> Void)?) {
        DispatchQueue.global().async {
            let albums = AlbumDAO.shared.getAlbums()
            var currentAlbums: [Album]
            if self.ablumIds.isEmpty {
                AppGroupUserDefaults.User.stickerAblums = albums.map({ $0.albumId })
                currentAlbums = albums
            } else {
                let albumMap: [String: Album] = albums.reduce(into: [:]) { $0[$1.albumId] = $1 }
                currentAlbums = self.ablumIds.compactMap { albumMap[$0] }
                if currentAlbums.count < albums.count {
                    let newAddedAlbums = albums.suffix(albums.count - currentAlbums.count)
                    currentAlbums += newAddedAlbums
                }
            }
            let items = currentAlbums.map({ StickerStoreItem(album: $0, stickers: StickerDAO.shared.getStickers(albumId: $0.albumId), isAdded: true) })
            DispatchQueue.main.async {
                completion?(items)
            }
        }
    }
    
    // TODO: fetch from server
    func fetchStoreStickers(completion: (Result<[StickerStoreItem], Error>) -> Void) {
        func alert(_ str: String) {
            AppDelegate.current.mainWindow.rootViewController?.alert(str)
        }
        let stickerStoreItems = AlbumDAO.shared.getAlbums().map({ StickerStoreItem(album: $0, stickers: StickerDAO.shared.getStickers(albumId: $0.albumId), isAdded: .random()) })
        completion(.success(stickerStoreItems))
    }
    
    // TODO: fetch from erver
    func fetchSticker(stickerId: String, completion: (Result<StickerStoreItem, Error>) -> Void) {
        if let album = AlbumDAO.shared.getAlbum(stickerId: stickerId) {
            completion(.success(StickerStoreItem(album: album, stickers: StickerDAO.shared.getStickers(albumId: album.albumId))))
        } else {
            //completion(.failure(error))
        }
    }
    
}

