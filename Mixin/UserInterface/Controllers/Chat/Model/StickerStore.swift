import Foundation
import MixinServices
import SDWebImage

enum StickerStore {
    
    struct StickerInfo {
        let album: Album
        let stickers: [StickerItem]
        var isAdded: Bool = false
    }
    
    private static let maxBannerCount = 3
    
    static func add(stickers stickerInfo: StickerInfo) {
        let albumId = stickerInfo.album.albumId
        let stickers = stickerInfo.stickers
        let stickerIds = stickers.map(\.stickerId)

        let jobId = RefreshStickerCacheJob(.remove(stickers: stickers, albumId: albumId)).getJobId()
        ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        
        if var albums = AppGroupUserDefaults.User.favoriteAlbums {
            let favoriteStickers = AppGroupUserDefaults.User.favoriteAlbumStickers
            AppGroupUserDefaults.User.favoriteAlbumStickers = Array(Set(stickerIds).union(favoriteStickers))
            albums.insert(albumId, at: 0)
            AppGroupUserDefaults.User.favoriteAlbums = albums
        } else {
            AppGroupUserDefaults.User.favoriteAlbumStickers = stickerIds
            AppGroupUserDefaults.User.favoriteAlbums = [albumId]
        }
        
        ConcurrentJobQueue.shared.addJob(job: RefreshStickerCacheJob(.add(stickers: stickers, albumId: albumId)))
    }
    
    static func remove(stickers stickerInfo: StickerInfo) {
        let albumId = stickerInfo.album.albumId
        let stickers = stickerInfo.stickers
        let stickerIds = stickers.map(\.stickerId)

        let jobId = RefreshStickerCacheJob(.add(stickers: stickers, albumId: albumId)).getJobId()
        ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        
        let favoriteStickers = AppGroupUserDefaults.User.favoriteAlbumStickers
        AppGroupUserDefaults.User.favoriteAlbumStickers = Array(Set(favoriteStickers).subtracting(Set(stickerIds)))
        if let albumIds = AppGroupUserDefaults.User.favoriteAlbums?.filter({ $0 != albumId }) {
            AppGroupUserDefaults.User.favoriteAlbums = albumIds
        }

        ConcurrentJobQueue.shared.addJob(job: RefreshStickerCacheJob(.remove(stickers: stickerInfo.stickers, albumId: albumId)))
    }
    
    static func refreshStickersIfNeeded() {
        if let date = AppGroupUserDefaults.User.stickerRefreshDate, date.timeIntervalSinceNow < .oneDay {
            return
        }
        ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob(.albums))
        AppGroupUserDefaults.User.stickerRefreshDate = Date()
    }
    
    static func loadStoreStickers(completion: @escaping (_ bannerStickerInfos: [StickerInfo], _ listStickerInfos: [StickerInfo]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var bannerStickerInfos: [StickerInfo] = []
            var listStickerInfos: [StickerInfo] = []
            let albums = AlbumDAO.shared.getAlbums()
            let favoriteAlbums = AppGroupUserDefaults.User.favoriteAlbums
            albums.forEach { album in
                let stickers = StickerDAO.shared.getStickers(albumId: album.albumId)
                let isAdded = favoriteAlbums?.contains(album.albumId) ?? false
                let stickerInfo = StickerInfo(album: album, stickers: stickers, isAdded: isAdded)
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
    
    static func loadMyStickers(completion: @escaping ([StickerInfo]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let stickerInfos: [StickerStore.StickerInfo]
            if let favoriteAlbums = AppGroupUserDefaults.User.favoriteAlbums {
                let albums = AlbumDAO.shared.getAlbums(with: favoriteAlbums)
                stickerInfos = albums.map({
                    StickerInfo(album: $0, stickers: StickerDAO.shared.getStickers(albumId: $0.albumId), isAdded: true)
                })
            } else {
                let albums = AlbumDAO.shared.getAlbums().filter({ !$0.banner.isNilOrEmpty })
                stickerInfos = albums.map({
                    StickerInfo(album: $0, stickers: StickerDAO.shared.getStickers(albumId: $0.albumId), isAdded: true)
                })
                let stickerIds = stickerInfos.reduce(into: [String]()) { result, stickerInfo in
                    result.append(contentsOf: stickerInfo.stickers.map(\.stickerId))
                }
                DispatchQueue.main.async {
                    AppGroupUserDefaults.User.hasNewStickers = true
                    AppGroupUserDefaults.User.favoriteAlbumStickers = stickerIds
                    AppGroupUserDefaults.User.favoriteAlbums = albums.map(\.albumId)
                }
            }
            completion(stickerInfos)
        }
    }
    
    static func loadSticker(stickerId: String, completion: @escaping (StickerInfo?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let album = AlbumDAO.shared.getAlbum(stickerId: stickerId) {
                let stickers = StickerDAO.shared.getStickers(albumId: album.albumId)
                let favoriteAlbums = AppGroupUserDefaults.User.favoriteAlbums
                let isAdded = favoriteAlbums != nil && favoriteAlbums!.contains(album.albumId)
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
