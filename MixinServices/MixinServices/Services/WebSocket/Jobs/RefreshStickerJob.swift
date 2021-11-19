import Foundation
import SDWebImage

public class RefreshStickerJob: AsynchronousJob {
    
    private let albumId: String?
    private let stickerId: String?
    private let prefetchStickers: Bool
    
    public init(albumId: String? = nil, stickerId: String? = nil, prefetchStickers: Bool = true) {
        self.albumId = albumId
        self.stickerId = stickerId
        self.prefetchStickers = prefetchStickers
    }
    
    override public func getJobId() -> String {
        if let stickerId = self.stickerId {
            return "refresh-sticker-\(stickerId)"
        } else if let albumId = self.albumId {
            return "refresh-album-\(albumId)"
        }
        return "refresh-albums"
    }

    public override func execute() -> Bool {
        if let stickerId = self.stickerId {
            StickerAPI.sticker(stickerId: stickerId) { (result) in
                switch result {
                case let .success(sticker):
                    DispatchQueue.global().async {
                        guard !MixinService.isStopProcessMessages else {
                            return
                        }
                        guard let stickerItem = StickerDAO.shared.insertOrUpdateSticker(sticker: sticker) else {
                            return
                        }
                        StickerPrefetcher.prefetch(stickers: [stickerItem])
                    }
                case let .failure(error):
                    reporter.report(error: error)
                }
                self.finishJob()
            }
        } else if let albumId = self.albumId {
            StickerAPI.stickers(albumId: albumId) { (result) in
                switch result {
                case let .success(stickers):
                    DispatchQueue.global().async {
                        guard !MixinService.isStopProcessMessages else {
                            return
                        }
                        let stickers = StickerDAO.shared.insertOrUpdateStickers(stickers: stickers, albumId: albumId)
                        if self.prefetchStickers {
                            StickerPrefetcher.prefetch(stickers: stickers)
                        }
                    }
                case let .failure(error):
                    reporter.report(error: error)
                }
                self.finishJob()
            }
        } else {
            let stickerAlbums = AlbumDAO.shared.getAblumsUpdateAt()
            StickerAPI.albums { (result) in
                switch result {
                case let .success(albums):
                    let icons = albums.compactMap({ URL(string: $0.iconUrl) })
                    let banners = albums.compactMap { album -> URL? in
                        if let banner = album.banner {
                            return URL(string: banner)
                        }
                        return nil
                    }
                    StickerPrefetcher.persistent.prefetchURLs(icons + banners)
                    
                    let newAlbums = albums.filter { stickerAlbums[$0.albumId] != $0.updatedAt }
                    guard !newAlbums.isEmpty else {
                        return
                    }
                    DispatchQueue.main.async {
                        if !AppGroupUserDefaults.User.hasNewStickers {
                            AppGroupUserDefaults.User.hasNewStickers = true
                        }
                    }
                    for album in albums {
                        DispatchQueue.global().async {
                            guard !MixinService.isStopProcessMessages else {
                                return
                            }
                            AlbumDAO.shared.insertOrUpdateAblum(album: album)
                            DispatchQueue.main.async {
                                ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob(albumId: album.albumId, prefetchStickers: !album.banner.isNilOrEmpty))
                            }
                        }
                    }
                case let .failure(error):
                    reporter.report(error: error)
                }
                self.finishJob()
            }
        }
        return true
    }
    
}
