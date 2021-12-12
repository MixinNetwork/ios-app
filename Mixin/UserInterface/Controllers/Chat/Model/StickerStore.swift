import Foundation
import SDWebImage
import MixinServices

enum StickerStore {
    
    struct StickerInfo {
        let album: Album
        let stickers: [StickerItem]
        var isAdded: Bool = false
    }
    
    private static let queue = DispatchQueue(label: "one.mixin.messenger.queue.StickerStore.operation")
    private static let maxBannerCount = 3

    static func updateAlbumsOrder(albumIds: [String]) {
        queue.async {
            AlbumDAO.shared.updateAlbumsOrder(albumdIds: albumIds)
        }
    }
    
    static func add(stickers stickerInfo: StickerInfo) {
        queue.async {
            AlbumDAO.shared.updateAlbum(with: stickerInfo.album.albumId, isAdded: true)
            moveStickerCacheInPersistentStorage(stickerInfo: stickerInfo)
        }
    }
    
    static func remove(stickers stickerInfo: StickerInfo) {
        queue.async {
            AlbumDAO.shared.updateAlbum(with: stickerInfo.album.albumId, isAdded: false)
            moveStickerCacheInPurgableStorage(stickerInfo: stickerInfo)
        }
    }
    
    static func refreshStickersIfNeeded() {
        let refreshSticker = { (needsMigration: Bool) in
            ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob(.albums(needsMigration: needsMigration)))
            AppGroupUserDefaults.User.stickerRefreshDate = Date()
        }
        if let date = AppGroupUserDefaults.User.stickerRefreshDate {
            if -date.timeIntervalSinceNow >= .oneDay {
                refreshSticker(false)
            }
        } else {
            refreshSticker(true)
        }
    }
    
    static func loadStoreStickers(completion: @escaping (_ bannerStickerInfos: [StickerInfo], _ listStickerInfos: [StickerInfo]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var bannerStickerInfos: [StickerInfo] = []
            var listStickerInfos: [StickerInfo] = []
            let albums = AlbumDAO.shared.getNonPersonalAlbums()
            albums.forEach { album in
                let stickers = StickerDAO.shared.getStickers(albumId: album.albumId)
                let stickerInfo = StickerInfo(album: album, stickers: stickers, isAdded: album.isAdded)
                if !album.banner.isNilOrEmpty, bannerStickerInfos.count < maxBannerCount {
                    bannerStickerInfos.append(stickerInfo)
                } else {
                    listStickerInfos.append(stickerInfo)
                }
            }
            DispatchQueue.main.async {
                completion(bannerStickerInfos, listStickerInfos)
            }
        }
    }
    
    static func loadAddedStickers(completion: @escaping ([StickerInfo]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let stickerInfos = AlbumDAO.shared.getAddedAlbums().map({
                StickerInfo(album: $0,
                            stickers: StickerDAO.shared.getStickers(albumId: $0.albumId),
                            isAdded: true)
            })
            completion(stickerInfos)
        }
    }
    
    static func loadSticker(stickerId: String, completion: @escaping (StickerInfo?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let album = AlbumDAO.shared.getAlbum(stickerId: stickerId) {
                if album.category == AlbumCategory.PERSONAL.rawValue {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                } else {
                    let stickers = StickerDAO.shared.getStickers(albumId: album.albumId)
                    DispatchQueue.main.async {
                        completion(StickerInfo(album: album, stickers: stickers, isAdded: album.isAdded))
                    }
                }
            } else {
                fetchSticker(stickerId: stickerId, completion: completion)
            }
        }
    }
    
}

extension StickerStore {
    
    private static func moveStickerCacheInPersistentStorage(stickerInfo: StickerInfo) {
        let purgable = SDImageCache.shared
        let persistent = SDImageCache.persistentSticker
        var prefetchUrls = [String]()
        for sticker in stickerInfo.stickers {
            if persistent.diskImageDataExists(withKey: sticker.assetUrl) {
                purgable.removeImageFromDisk(forKey: sticker.assetUrl)
            } else if let data = purgable.diskImageData(forKey: sticker.assetUrl) {
                persistent.storeImageData(toDisk: data, forKey: sticker.assetUrl)
                purgable.removeImageFromDisk(forKey: sticker.assetUrl)
            } else {
                prefetchUrls.append(sticker.assetUrl)
            }
        }
        if let banner = stickerInfo.album.banner {
            if persistent.diskImageDataExists(withKey: banner) {
                purgable.removeImageFromDisk(forKey: banner)
            } else if let data = purgable.diskImageData(forKey: banner) {
                persistent.storeImageData(toDisk: data, forKey: banner)
                purgable.removeImageFromDisk(forKey: banner)
            } else {
                prefetchUrls.append(banner)
            }
        }
        let urls = prefetchUrls.compactMap(URL.init)
        StickerPrefetcher.prefetchPersistently(urls: urls, albumId: stickerInfo.album.albumId)
    }
    
    private static func moveStickerCacheInPurgableStorage(stickerInfo: StickerInfo) {
        StickerPrefetcher.cancelPrefetching(albumId: stickerInfo.album.albumId)
        let purgable = SDImageCache.shared
        let persistent = SDImageCache.persistentSticker
        for sticker in stickerInfo.stickers {
            guard !StickerDAO.shared.isFavoriteSticker(stickerId: sticker.stickerId) else {
                continue
            }
            if !purgable.diskImageDataExists(withKey: sticker.assetUrl), let data = persistent.diskImageData(forKey: sticker.assetUrl) {
                purgable.storeImageData(toDisk: data, forKey: sticker.assetUrl)
            }
            persistent.removeImageFromDisk(forKey: sticker.assetUrl)
        }
        if let banner = stickerInfo.album.banner {
            if !purgable.diskImageDataExists(withKey: banner), let data = persistent.diskImageData(forKey: banner) {
                purgable.storeImageData(toDisk: data, forKey: banner)
            }
            persistent.removeImageFromDisk(forKey: banner)
        }
    }
    
}

extension StickerStore {
    
    private static func fetchSticker(stickerId: String, completion: @escaping (StickerInfo?) -> Void) {
        var stickerInfo: StickerInfo?
        let queue = DispatchQueue(label: "one.mixin.messenger.StickerStore.fetchSticker", attributes: .concurrent)
        let group = DispatchGroup()
        group.enter()
        queue.async(group: group) {
            let stickerAlbums = AlbumDAO.shared.getAblumsUpdateAt()
            StickerAPI.albums { (result) in
                switch result {
                case let .success(albums):
                    let newAlbums = albums.filter { stickerAlbums[$0.albumId] != $0.updatedAt }
                    guard !newAlbums.isEmpty else {
                        group.leave()
                        return
                    }
                    for album in newAlbums {
                        group.enter()
                        queue.async(group: group) {
                            AlbumDAO.shared.insertOrUpdateAblum(album: album)
                            StickerAPI.stickers(albumId: album.albumId) { (result) in
                                switch result {
                                case let .success(stickers):
                                    let stickers = StickerDAO.shared.insertOrUpdateStickers(stickers: stickers, albumId: album.albumId)
                                    if stickers.contains(where: { $0.stickerId == stickerId }) {
                                        stickerInfo = StickerInfo(album: album, stickers: stickers)
                                    }
                                case let .failure(error):
                                    reporter.report(error: error)
                                }
                                group.leave()
                            }
                        }
                    }
                case let .failure(error):
                    reporter.report(error: error)
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion(stickerInfo)
        }
    }
    
}
