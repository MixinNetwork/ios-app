import Foundation
import SDWebImage

public class RefreshStickerJob: AsynchronousJob {
    
    public enum Content {
        case albums
        case sticker(id: String)
        case stickers(albumId: String, prefetch: Bool)
    }
    
    private let content: Content?
    
    public init(_ content: Content) {
        self.content = content
    }
    
    override public func getJobId() -> String {
        switch content {
        case .albums:
            return "refresh-albums"
        case let .sticker(id):
            return "refresh-sticker-\(id)"
        case let .stickers(albumId, _):
            return "refresh-album-\(albumId)"
        case .none:
            assertionFailure("No content")
            return ""
        }
    }
    
    public override func execute() -> Bool {
        switch content {
        case .albums:
            let stickerAlbums = AlbumDAO.shared.getAblumsUpdateAt()
            StickerAPI.albums { (result) in
                switch result {
                case let .success(albums):
                    var urls = [URL]()
                    albums.forEach { album in
                        if let url = URL(string: album.iconUrl) {
                            urls.append(url)
                        }
                        if let banner = album.banner, let url = URL(string: banner) {
                            urls.append(url)
                        }
                    }
                    StickerPrefetcher.persistent.prefetchURLs(urls)
                    
                    let newAlbums = albums.filter { stickerAlbums[$0.albumId] != $0.updatedAt }
                    guard !newAlbums.isEmpty else {
                        return
                    }
                    DispatchQueue.main.async {
                        if !AppGroupUserDefaults.User.hasNewStickers {
                            AppGroupUserDefaults.User.hasNewStickers = true
                        }
                    }
                    for album in newAlbums {
                        DispatchQueue.global().async {
                            guard !MixinService.isStopProcessMessages else {
                                return
                            }
                            AlbumDAO.shared.insertOrUpdateAblum(album: album)
                            DispatchQueue.main.async {
                                ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob(.stickers(albumId: album.albumId, prefetch: !album.banner.isNilOrEmpty)))
                            }
                        }
                    }
                case let .failure(error):
                    reporter.report(error: error)
                }
                self.finishJob()
            }
        case let .sticker(id):
            StickerAPI.sticker(stickerId: id) { (result) in
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
        case let .stickers(albumId, prefetch):
            StickerAPI.stickers(albumId: albumId) { (result) in
                switch result {
                case let .success(stickers):
                    DispatchQueue.global().async {
                        guard !MixinService.isStopProcessMessages else {
                            return
                        }
                        let stickers = StickerDAO.shared.insertOrUpdateStickers(stickers: stickers, albumId: albumId)
                        if prefetch {
                            let urls = stickers.map(\.assetUrl).compactMap(URL.init)
                            StickerPrefetcher.persistent.prefetchURLs(urls)
                        }
                    }
                case let .failure(error):
                    reporter.report(error: error)
                }
                self.finishJob()
            }
        case .none:
            assertionFailure("No content")
            finishJob()
        }
        return true
    }
    
}
