import Foundation
import SDWebImage

public class RefreshStickerJob: AsynchronousJob {
    
    public enum Content {
        case albums
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
        case let .albums:
            let stickerAlbums = AlbumDAO.shared.getAlbumsUpdatedAt()
            StickerAPI.albums { (result) in
                switch result {
                case let .success(albums):
                    let urls = albums.map(\.iconUrl).compactMap(URL.init)
                    StickerPrefetcher.persistent.prefetchURLs(urls)
                    
                    var newAlbums = albums.filter { stickerAlbums[$0.albumId] != $0.updatedAt }
                    guard !newAlbums.isEmpty else {
                        AppGroupUserDefaults.User.stickerRefreshDate = Date()
                        return
                    }
                    
                    if AppGroupUserDefaults.User.stickerRefreshDate == nil {
                        newAlbums = newAlbums.sorted { $0.updatedAt < $1.updatedAt }
                        let counter = Counter(value: 0)
                        for (index, album) in newAlbums.enumerated() {
                            if !album.banner.isNilOrEmpty {
                                newAlbums[index].isAdded = true
                                newAlbums[index].orderedAt = counter.advancedValue
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
                    AppGroupUserDefaults.User.hasNewStickers = true
                    AppGroupUserDefaults.User.stickerRefreshDate = Date()
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
