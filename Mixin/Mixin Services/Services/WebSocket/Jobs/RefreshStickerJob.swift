import Foundation
import SDWebImage

class RefreshStickerJob: BaseJob {

    private let albumId: String?

    init(albumId: String? = nil) {
        self.albumId = albumId
    }

    override func getJobId() -> String {
        guard let albumId = self.albumId else {
            return "refresh-sticker"
        }
        return "refresh-sticker-\(albumId)"
    }

    override func run() throws {
        if let albumId = self.albumId {
            try RefreshStickerJob.cacheStickers(albumId: albumId)
        } else {
            let stickerAlbums = AlbumDAO.shared.getAblumsUpdateAt()
            switch StickerAPI.shared.albums() {
            case let .success(albums):
                let icons = albums.compactMap({ URL(string: $0.iconUrl) })
                StickerPrefetcher.persistentPrefetcher.prefetchURLs(icons)
                for album in albums {
                    guard stickerAlbums[album.albumId] != album.updatedAt else {
                        continue
                    }
                    try RefreshStickerJob.cacheStickers(albumId: album.albumId)
                    AlbumDAO.shared.insertOrUpdateAblum(album: album)
                }

                if !AppGroupUserDefaults.Database.isStickersUpgraded {
                    MessageDAO.shared.updateOldStickerMessages()
                    AppGroupUserDefaults.Database.isStickersUpgraded = true
                }
            case let .failure(error):
                throw error
            }
        }
    }

    static func cacheStickers(albumId: String) throws {
        switch StickerAPI.shared.stickers(albumId: albumId) {
        case let .success(stickers):
            StickerDAO.shared.insertOrUpdateStickers(stickers: stickers, albumId: albumId)
            let stickers = StickerDAO.shared.getStickers(albumId: albumId)
            StickerPrefetcher.prefetch(stickers: stickers)
        case let .failure(error):
            throw error
        }
    }
    
}

