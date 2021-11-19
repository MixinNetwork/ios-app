import Foundation
import MixinServices
import SDWebImage

enum StickerStore {
    
    struct StickerInfo {
        let album: Album
        let stickers: [StickerItem]
        var isAdded: Bool = false
    }
    
    private static let bannerMaxCount = 3
    
    static func add(stickers stickerInfo: StickerInfo) {
        let albumId = stickerInfo.album.albumId
        if var albumIds = AppGroupUserDefaults.User.stickerAblums {
            albumIds.insert(albumId, at: 0)
            AppGroupUserDefaults.User.stickerAblums = albumIds
        } else {
            AppGroupUserDefaults.User.stickerAblums = [albumId]
        }
        ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob(albumId: albumId))
    }
    
    static func remove(stickers stickerInfo: StickerInfo) {
        guard let albumIds = AppGroupUserDefaults.User.stickerAblums else {
            return
        }
        let jobId = RefreshStickerJob(albumId: stickerInfo.album.albumId).getJobId()
        ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        stickerInfo.stickers.forEach { SDImageCache.persistentSticker.removeImageFromDisk(forKey: $0.assetUrl) }
        AppGroupUserDefaults.User.stickerAblums = albumIds.filter({ $0 != stickerInfo.album.albumId })
    }
        
    static func refreshStickersIfNeeded() {
        let date = AppGroupUserDefaults.User.stickerUpdateDate
        guard date == nil || -date!.timeIntervalSinceNow > TimeInterval.oneDay else {
            return
        }
        AppGroupUserDefaults.User.stickerUpdateDate = Date()
        ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob())
    }
    
    static func loadStoreStickers(completion: @escaping (_ bannerStickerInfos: [StickerInfo], _ listStickerInfos: [StickerInfo]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var bannerStickerInfos: [StickerInfo] = []
            var listStickerInfos: [StickerInfo] = []
            let albums = AlbumDAO.shared.getAlbums()
            let stickerAblums = AppGroupUserDefaults.User.stickerAblums
            albums.forEach { album in
                let stickers = StickerDAO.shared.getStickers(albumId: album.albumId)
                let isAdded = stickerAblums?.contains(album.albumId) ?? false
                let stickerInfo = StickerInfo(album: album, stickers: stickers, isAdded: isAdded)
                if !album.banner.isNilOrEmpty, bannerStickerInfos.count < bannerMaxCount {
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
    
    static func loadMyStickers(completion: @escaping ([StickerInfo]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let albums: [Album]
            if let albumIds = AppGroupUserDefaults.User.stickerAblums {
                albums = AlbumDAO.shared.getAlbums(with: albumIds)
            } else {
                albums = AlbumDAO.shared.getAlbums().filter({ !$0.banner.isNilOrEmpty })
                DispatchQueue.main.async {
                    AppGroupUserDefaults.User.hasNewStickers = true
                    AppGroupUserDefaults.User.stickerAblums = albums.map(\.albumId)
                }
            }
            let items = albums.map({
                StickerInfo(album: $0,
                            stickers: StickerDAO.shared.getStickers(albumId: $0.albumId),
                            isAdded: true)
            })
            completion(items)
        }
    }
    
    
    static func loadSticker(stickerId: String, completion: @escaping (StickerInfo?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let album = AlbumDAO.shared.getAlbum(stickerId: stickerId) {
                let stickers = StickerDAO.shared.getStickers(albumId: album.albumId)
                let albumIds = AppGroupUserDefaults.User.stickerAblums
                let isAdded = albumIds != nil && albumIds!.contains(album.albumId)
                DispatchQueue.main.async {
                    completion(StickerInfo(album: album, stickers: stickers, isAdded: isAdded))
                }
            } else {
                fetchSticker(stickerId: stickerId, completion: completion)
            }
        }
    }
    
}

extension StickerStore {
    
    private static func fetchSticker(stickerId: String, completion: @escaping (StickerInfo?) -> Void) {
        var stickerInfo: StickerInfo?
        let queue = DispatchQueue(label: "one.mixin.messenger.StickerStore", attributes: .concurrent)
        let group = DispatchGroup()
        group.enter()
        queue.async(group: group) {
            let stickerAlbums = AlbumDAO.shared.getAblumsUpdateAt()
            StickerAPI.albums { (result) in
                switch result {
                case let .success(albums):
                    let newAlbums = albums.filter { stickerAlbums[$0.albumId] != $0.updatedAt }
                    guard !newAlbums.isEmpty else {
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
