import MixinServices

class StickersStoreManager {
    
    private static var privateShared : StickersStoreManager?
    
    private var albumIds: [String]? {
        return AppGroupUserDefaults.User.stickerAblums
    }
    private let bannerItemsMaxCount = 3
    private let checkStickerInterval: TimeInterval = 60 * 60 * 24
    private let queue = DispatchQueue(label: "one.mixin.messenger.StickersStoreManager")
    
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
        if var albumIds = albumIds {
            albumIds.insert(album.albumId, at: 0)
            AppGroupUserDefaults.User.stickerAblums = albumIds
        } else {
            AppGroupUserDefaults.User.stickerAblums = [album.albumId]
        }
    }
    
    func remove(album: Album) {
        guard let albumIds = albumIds else {
            return
        }
        AppGroupUserDefaults.User.stickerAblums = albumIds.filter({ $0 != album.albumId })
    }
    
    func updateStickerAlbumsSequence(albumIds: [String]) {
        AppGroupUserDefaults.User.stickerAblums = albumIds
    }
    
    func loadMyStickers(completion: @escaping ([StickerStoreItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var myAlbums: [Album]
            if let albumIds = self.albumIds {
                myAlbums = AlbumDAO.shared.getAlbums(with: albumIds)
            } else {
                myAlbums = AlbumDAO.shared.getAlbums()
                AppGroupUserDefaults.User.stickerAblums = myAlbums.map(\.albumId)
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
                if let banner = album.banner, banner.count > 0, bannerItems.count < self.bannerItemsMaxCount {
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
            let isAdded = albumIds != nil && albumIds!.contains(album.albumId)
            completion(StickerStoreItem(album: album, stickers: StickerDAO.shared.getStickers(albumId: album.albumId), isAdded: isAdded))
        } else {
            fetchAllStickers(withTarget: stickerId, completion: completion)
        }
    }
    
    func checkNewStickersIfNeeded(completion: @escaping (Bool) -> Void) {
        let date = AppGroupUserDefaults.User.stickerUpdateDate
        guard date == nil || -date!.timeIntervalSinceNow > checkStickerInterval else {
            return
        }
        queue.async {
            let stickerAlbums = AlbumDAO.shared.getAblumsUpdateAt()
            StickerAPI.albums { (result) in
                let hasNewStickers: Bool
                switch result {
                case let .success(albums):
                    hasNewStickers = albums.contains(where: { $0.updatedAt != stickerAlbums[$0.albumId] })
                case let .failure(error):
                    hasNewStickers = false
                    reporter.report(error: error)
                }
                DispatchQueue.main.async {
                    if hasNewStickers {
                        ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob())
                    }
                    AppGroupUserDefaults.User.hasNewStickers = AppGroupUserDefaults.User.hasNewStickers ? true : hasNewStickers
                    AppGroupUserDefaults.User.stickerUpdateDate = Date()
                    completion(hasNewStickers)
                }
            }
        }
    }
    
}

extension StickersStoreManager {
    
    private func fetchAllStickers(withTarget stickerId: String, completion: @escaping (StickerStoreItem?) -> Void) {
        let stickerWorkingGroup = DispatchGroup()
        var stickerStoreItem: StickerStoreItem?
        stickerWorkingGroup.enter()
        queue.async {
            let stickerAlbums = AlbumDAO.shared.getAblumsUpdateAt()
            StickerAPI.albums { (result) in
                switch result {
                case let .success(albums):
                    for album in albums {
                        guard stickerAlbums[album.albumId] != album.updatedAt else {
                            continue
                        }
                        guard !MixinService.isStopProcessMessages else {
                            return
                        }
                        AlbumDAO.shared.insertOrUpdateAblum(album: album)
                        
                        stickerWorkingGroup.enter()
                        StickerAPI.stickers(albumId: album.albumId) { (result) in
                            switch result {
                            case let .success(stickers):
                                guard !MixinService.isStopProcessMessages else {
                                    return
                                }
                                let stickers = StickerDAO.shared.insertOrUpdateStickers(stickers: stickers, albumId: album.albumId)
                                if stickers.contains(where: { $0.stickerId == stickerId }) {
                                    stickerStoreItem = StickerStoreItem(album: album, stickers: stickers)
                                }
                            case let .failure(error):
                                reporter.report(error: error)
                            }
                            stickerWorkingGroup.leave()
                        }
                    }
                case let .failure(error):
                    reporter.report(error: error)
                }
                stickerWorkingGroup.leave()
            }
        }
        stickerWorkingGroup.notify(queue: queue) {
            DispatchQueue.main.async {
                completion(stickerStoreItem)
            }
        }
    }
    
}
