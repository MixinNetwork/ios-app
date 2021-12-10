import Foundation
import SDWebImage

public class RefreshStickerJob: AsynchronousJob {
    
    public enum Content {
        case albums(needsMigration: Bool)
        case sticker(id: String)
        case stickers(albumId: String, automaticallyDownloads: Bool)
    }
    
    private let content: Content
    
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
        }
    }
    
    public override func execute() -> Bool {
        switch content {
        case let .albums(needsMigration):
            let stickerAlbums = AlbumDAO.shared.getAblumsUpdateAt()
            StickerAPI.albums { (result) in
                switch result {
                case let .success(albums):
                    let urls = albums.map(\.iconUrl).compactMap(URL.init)
                    StickerPrefetcher.persistent.prefetchURLs(urls)
                    
                    var newAlbums = albums.filter { stickerAlbums[$0.albumId] != $0.updatedAt }
                    if newAlbums.isEmpty {
                        return
                    }
                    DispatchQueue.main.async {
                        if !AppGroupUserDefaults.User.hasNewStickers {
                            AppGroupUserDefaults.User.hasNewStickers = true
                        }
                    }
                    if needsMigration {
                        newAlbums = newAlbums.sorted(by: { $0.updatedAt > $1.updatedAt })
                        var order = 0
                        for (index, album) in newAlbums.enumerated() {
                            if !album.banner.isNilOrEmpty {
                                newAlbums[index].isAdded = true
                                newAlbums[index].orderedAt = "\(order)"
                                order += 1
                            } else if album.category == AlbumCategory.PERSONAL.rawValue {
                                newAlbums[index].isAdded = true
                            }
                        }
                    }
                    var purgableBannerUrls = [URL]()
                    var persistentBannerUrls = [URL]()
                    for album in newAlbums {
                        if let banner = album.banner, let url = URL(string: banner) {
                            if album.isAdded {
                                persistentBannerUrls.append(url)
                            } else {
                                purgableBannerUrls.append(url)
                            }
                        }
                        DispatchQueue.global().async {
                            guard !MixinService.isStopProcessMessages else {
                                return
                            }
                            AlbumDAO.shared.insertOrUpdateAblum(album: album)
                            DispatchQueue.main.async {
                                let job = RefreshStickerJob(.stickers(albumId: album.albumId, automaticallyDownloads: album.automaticallyDownloads))
                                ConcurrentJobQueue.shared.addJob(job: job)
                            }
                        }
                    }
                    StickerPrefetcher.persistent.prefetchURLs(persistentBannerUrls)
                    StickerPrefetcher.purgable.prefetchURLs(purgableBannerUrls)
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
        case let .stickers(albumId, automaticallyDownloads):
            StickerAPI.stickers(albumId: albumId) { (result) in
                switch result {
                case let .success(stickers):
                    DispatchQueue.global().async {
                        guard !MixinService.isStopProcessMessages else {
                            return
                        }
                        let stickers = StickerDAO.shared.insertOrUpdateStickers(stickers: stickers, albumId: albumId)
                        if automaticallyDownloads {
                            StickerPrefetcher.prefetch(stickers: stickers)
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
