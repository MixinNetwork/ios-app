import Foundation
import SDWebImage

public class RefreshStickerJob: AsynchronousJob {
    
    private let albumId: String?
    private let stickerId: String?
    
    public init(albumId: String? = nil, stickerId: String? = nil) {
        self.albumId = albumId
        self.stickerId = stickerId
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
                        StickerPrefetcher.prefetch(stickers: stickers)
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
                    StickerPrefetcher.persistent.prefetchURLs(icons)
                    for album in albums {
                        guard stickerAlbums[album.albumId] != album.updatedAt else {
                            continue
                        }
                        DispatchQueue.global().async {
                            guard !MixinService.isStopProcessMessages else {
                                return
                            }
                            AlbumDAO.shared.insertOrUpdateAblum(album: album)
                            DispatchQueue.main.async {
                                ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob(albumId: album.albumId))
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
