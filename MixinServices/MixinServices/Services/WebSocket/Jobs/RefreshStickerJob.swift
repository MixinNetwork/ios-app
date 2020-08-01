import Foundation
import SDWebImage

public class RefreshStickerJob: AsynchronousJob {
    
    private let albumId: String?
    
    public init(albumId: String? = nil) {
        self.albumId = albumId
    }
    
    override public func getJobId() -> String {
        guard let albumId = self.albumId else {
            return "refresh-sticker"
        }
        return "refresh-sticker-\(albumId)"
    }

    public override func execute() -> Bool {
        if let albumId = self.albumId {
            StickerAPI.stickers(albumId: albumId) { (result) in
                switch result {
                case let .success(stickers):
                    DispatchQueue.global().async {
                        guard !MixinService.isStopProcessMessages else {
                            return
                        }

                        StickerDAO.shared.insertOrUpdateStickers(stickers: stickers, albumId: albumId)
                        let stickers = StickerDAO.shared.getStickers(albumId: albumId)
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
