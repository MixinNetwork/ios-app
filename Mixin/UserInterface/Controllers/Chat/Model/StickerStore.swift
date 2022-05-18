import Foundation
import SDWebImage
import MixinServices

enum StickerStore {
        
    private static let queue = DispatchQueue(label: "one.mixin.messenger.queue.StickerStore.operation")

    static func updateAlbumsOrder(albumIds: [String]) {
        queue.async {
            AlbumDAO.shared.updateAlbumsOrder(albumdIds: albumIds)
        }
    }
    
    static func add(item: AlbumItem) {
        queue.async {
            AlbumDAO.shared.updateAlbum(with: item.album.albumId, isAdded: true)
            moveStickerCacheInPersistentStorage(item: item)
        }
    }
    
    static func remove(item: AlbumItem) {
        queue.async {
            AlbumDAO.shared.updateAlbum(with: item.album.albumId, isAdded: false)
            moveStickerCacheInPurgableStorage(item: item)
        }
    }
    
    static func refreshStickersIfNeeded() {
        let shouldRefresh: Bool
        if let date = AppGroupUserDefaults.User.stickerRefreshDate {
            shouldRefresh = -date.timeIntervalSinceNow >= .day
        } else {
            shouldRefresh = true
        }
        if shouldRefresh {
            ConcurrentJobQueue.shared.addJob(job: RefreshAlbumJob())
        }
    }
    
    static func loadAddedAlbums(completion: @escaping ([AlbumItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let items = AlbumDAO.shared.getAddedAlbums().map({
                AlbumItem(album: $0, stickers: StickerDAO.shared.getStickers(albumId: $0.albumId))
            })
            completion(items)
        }
    }
    
    static func loadAlbum(stickerId: String, albumId: String?, completion: @escaping (AlbumItem?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let album = AlbumDAO.shared.getAlbum(stickerId: stickerId, category: .SYSTEM) {
                let albumItem = AlbumItem(album: album, stickers: StickerDAO.shared.getStickers(albumId: album.albumId))
                DispatchQueue.main.async {
                    completion(albumItem)
                }
            } else if let albumId = albumId, !albumId.isEmpty {
                fetchStickers(albumId: albumId, completion: completion)
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
}

extension StickerStore {
    
    private static func moveStickerCacheInPersistentStorage(item: AlbumItem) {
        let purgable = SDImageCache.shared
        let persistent = SDImageCache.persistentSticker
        var prefetchUrls = [String]()
        for sticker in item.stickers {
            if persistent.diskImageDataExists(withKey: sticker.assetUrl) {
                purgable.removeImageFromDisk(forKey: sticker.assetUrl)
            } else if let data = purgable.diskImageData(forKey: sticker.assetUrl) {
                persistent.storeImageData(toDisk: data, forKey: sticker.assetUrl)
                purgable.removeImageFromDisk(forKey: sticker.assetUrl)
            } else {
                prefetchUrls.append(sticker.assetUrl)
            }
        }
        if let banner = item.album.banner {
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
        StickerPrefetcher.prefetchPersistently(urls: urls, albumId: item.album.albumId)
    }
    
    private static func moveStickerCacheInPurgableStorage(item: AlbumItem) {
        StickerPrefetcher.cancelPrefetching(albumId: item.album.albumId)
        let purgable = SDImageCache.shared
        let persistent = SDImageCache.persistentSticker
        for sticker in item.stickers {
            guard !StickerDAO.shared.isFavoriteSticker(stickerId: sticker.stickerId) else {
                continue
            }
            if !purgable.diskImageDataExists(withKey: sticker.assetUrl), let data = persistent.diskImageData(forKey: sticker.assetUrl) {
                purgable.storeImageData(toDisk: data, forKey: sticker.assetUrl)
            }
            persistent.removeImageFromDisk(forKey: sticker.assetUrl)
        }
        if let banner = item.album.banner {
            if !purgable.diskImageDataExists(withKey: banner), let data = persistent.diskImageData(forKey: banner) {
                purgable.storeImageData(toDisk: data, forKey: banner)
            }
            persistent.removeImageFromDisk(forKey: banner)
        }
    }
    
    private static func fetchStickers(albumId: String, completion: @escaping (AlbumItem?) -> Void) {
        var albumItem: AlbumItem?
        switch StickerAPI.album(albumId: albumId) {
        case let .success(album):
            AlbumDAO.shared.insertOrUpdateAblum(album: album)
            switch StickerAPI.stickers(albumId: albumId) {
            case let .success(stickers):
                let stickers = StickerDAO.shared.insertOrUpdateStickers(stickers: stickers, albumId: albumId)
                albumItem = AlbumItem(album: album, stickers: stickers)
            case let .failure(error):
                reporter.report(error: error)
            }
        case let .failure(error):
            reporter.report(error: error)
        }
        DispatchQueue.main.async {
            completion(albumItem)
        }
    }
    
}
