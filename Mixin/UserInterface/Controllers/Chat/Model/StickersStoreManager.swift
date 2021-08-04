import MixinServices

class StickersStoreManager {
    
    private static var privateShared : StickersStoreManager?
    
    private let bannerItemsCount = 3
    private var shouldCheckNewStickers = true
    private var albumIds: [String]? {
        return AppGroupUserDefaults.User.stickerAblums
    }
    
    class func shared() -> StickersStoreManager {
        guard let shared = privateShared else {
            privateShared = StickersStoreManager()
            return privateShared!
        }
        return shared
    }
    
    class func destroy() {
        privateShared = nil
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
        if let myAlbumsId = albumIds {
            AppGroupUserDefaults.User.stickerAblums = Array(Set(myAlbumsId + [album.albumId]))
        } else {
            AppGroupUserDefaults.User.stickerAblums = [album.albumId]
        }
    }
    
    func remove(album: Album) {
        guard let myAlbumsId = albumIds else {
            return
        }
        AppGroupUserDefaults.User.stickerAblums = myAlbumsId.filter({ $0 != album.albumId })
    }
    
    func updateStickerAlbumSequence(albumIds: [String]) {
        AppGroupUserDefaults.User.stickerAblums = albumIds
    }
    
    func loadMyStickers(completion: @escaping ([StickerStoreItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var myAlbums: [Album]
            if let albumIds = self.albumIds {
                myAlbums = AlbumDAO.shared.getAlbums(with: albumIds)
            } else {
                myAlbums = AlbumDAO.shared.getAlbums()
                AppGroupUserDefaults.User.stickerAblums = myAlbums.map({ $0.albumId })
            }
            let items = myAlbums.map({
                StickerStoreItem(album: $0,
                                 stickers: StickerDAO.shared.getStickers(albumId: $0.albumId),
                                 isAdded: true)
            })
            completion(items)
        }
    }
    
    func loadStoreStickers(completion: @escaping (_ bannerItems: [StickerStoreItem], _ listItems: [StickerStoreItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var bannerItems: [StickerStoreItem] = []
            var listItems: [StickerStoreItem] = []
            AlbumDAO.shared.getAlbums().forEach { album in
                let item = StickerStoreItem(album: album,
                                            stickers: StickerDAO.shared.getStickers(albumId: album.albumId),
                                            isAdded: (self.albumIds?.contains(album.albumId)) ?? false)
                if album.banner != nil && bannerItems.count < self.bannerItemsCount {
                    bannerItems.append(item)
                } else {
                    listItems.append(item)
                }
            }
            DispatchQueue.main.async {
                completion(bannerItems, listItems)
            }
        }
    }
    
    func loadSticker(stickerId: String, completion: @escaping (StickerStoreItem?) -> Void) {
        if let album = AlbumDAO.shared.getAlbum(stickerId: stickerId) {
            completion((StickerStoreItem(album: album, stickers: StickerDAO.shared.getStickers(albumId: album.albumId))))
        } else {
            completion(nil)
        }
    }
    
    func loadStickerIfAdded(stickerId: String) -> StickerStoreItem? {
        guard let albumIds = albumIds, let album = AlbumDAO.shared.getAlbum(stickerId: stickerId), albumIds.contains(album.albumId) else {
            return nil
        }
        return StickerStoreItem(album: album, stickers: StickerDAO.shared.getStickers(albumId: album.albumId), isAdded: true)
    }
    
    func checkNewStickersIfNeeded(completion: @escaping (Bool) -> Void) {
        guard shouldCheckNewStickers else {
            return
        }
        shouldCheckNewStickers = false
        DispatchQueue.main.async {
            completion(true)
        }
    }
    
}
