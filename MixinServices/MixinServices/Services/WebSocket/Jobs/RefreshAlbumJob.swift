import Foundation

public class RefreshAlbumJob: BaseJob {
    
    public static let didRefreshNotification = Notification.Name("one.mixin.services.RefreshAlbumJob.DidRefresh")
    
    public override func getJobId() -> String {
        "refresh-albums"
    }
    
    public override func run() throws {
        switch StickerAPI.albums() {
        case let .success(albums):
            let albumsUpdatedAt = AlbumDAO.shared.getAlbumsUpdatedAt()
            var newAlbums = albums.filter { albumsUpdatedAt[$0.albumId] != $0.updatedAt }
            if AppGroupUserDefaults.User.stickerRefreshDate == nil {
                let newAlbumIds = newAlbums.map(\.albumId)
                let bannerAlbums = albums
                    .filter { !$0.banner.isNilOrEmpty && !newAlbumIds.contains($0.albumId) }
                newAlbums.append(contentsOf: bannerAlbums)
            }
            guard !newAlbums.isEmpty else {
                AppGroupUserDefaults.User.stickerRefreshDate = Date()
                return
            }
            let urls = newAlbums.map(\.iconUrl).compactMap(URL.init)
            StickerPrefetcher.persistent.prefetchURLs(urls)
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
                switch StickerAPI.stickers(albumId: album.albumId) {
                case let .success(stickers):
                    guard !MixinService.isStopProcessMessages else {
                        return
                    }
                    AlbumDAO.shared.insertOrUpdateAblum(album: album)
                    let stickers = StickerDAO.shared.insertOrUpdateStickers(stickers: stickers, albumId: album.albumId)
                    if album.automaticallyDownloads {
                        StickerPrefetcher.prefetch(stickers: stickers)
                    }
                case let .failure(error):
                    if error.worthReporting {
                        reporter.report(error: error)
                    }
                }
            }
            StickerPrefetcher.persistent.prefetchURLs(persistentBannerUrls)
            StickerPrefetcher.purgable.prefetchURLs(purgableBannerUrls)
            AppGroupUserDefaults.User.hasNewStickers = true
            AppGroupUserDefaults.User.stickerRefreshDate = Date()
            NotificationCenter.default.post(onMainThread: Self.didRefreshNotification, object: self)
        case let .failure(error):
            if error.worthReporting {
                reporter.report(error: error)
            }
        }
    }
    
}
