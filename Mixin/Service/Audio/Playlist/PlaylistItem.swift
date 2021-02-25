import Foundation
import AVFoundation
import GRDB
import MixinServices

final class PlaylistItem {
    
    let id: String
    let asset: AVURLAsset
    let metadata: Metadata
    
    internal init(id: String, asset: AVURLAsset, metadata: PlaylistItem.Metadata) {
        self.id = id
        self.asset = asset
        self.metadata = metadata
    }
    
    init(message: MessageItem) {
        let url = AttachmentContainer.url(for: .files, filename: message.mediaUrl)
        let filename = message.name ?? message.mediaUrl ?? ""
        self.id = message.messageId
        self.asset = AVURLAsset(url: url)
        self.metadata = Metadata(asset: asset, filename: filename)
    }
    
    init?(urlString: String) {
        guard let url = URL(string: urlString) else {
            return nil
        }
        guard let id = url.absoluteString.sha1 else {
            return nil
        }
        self.id = id
        self.asset = AVURLAsset(url: url)
        self.metadata = Metadata(asset: asset, filename: url.lastPathComponent)
    }
    
}

extension PlaylistItem: TableRecord {
    
    public static let databaseTableName = Message.databaseTableName
    
}

extension PlaylistItem: Decodable, DatabaseColumnConvertible, MixinFetchableRecord {
    
    enum InitializationError: Error {
        case invalidMediaURL
    }
    
    enum CodingKeys: String, CodingKey {
        case messageId = "id"
        case conversationId = "conversation_id"
        case mediaURL = "media_url"
        case name
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let messageId = try container.decode(String.self, forKey: .messageId)
        guard let mediaURL = try container.decodeIfPresent(String.self, forKey: .mediaURL), !mediaURL.isEmpty else {
            throw InitializationError.invalidMediaURL
        }
        let filename = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? mediaURL
        let url = AttachmentContainer.url(for: .files, filename: mediaURL)
        let asset = AVURLAsset(url: url)
        let metadata = Metadata(asset: asset, filename: filename)
        self.init(id: messageId, asset: asset, metadata: metadata)
    }
    
}

extension PlaylistItem {
    
    enum Source {
        case message(conversationId: String, messageId: String)
        case online(String)
    }
    
    class Metadata {
        
        let image: UIImage?
        let title: String?
        let subtitle: String?
        
        init(asset: AVURLAsset, filename: String) {
            var image: UIImage?
            var title: String?
            var subtitle: String?
            for metadata in asset.commonMetadata {
                switch metadata.commonKey {
                case AVMetadataKey.commonKeyArtwork:
                    if let data = metadata.dataValue, let artwork = UIImage(data: data) {
                        image = artwork
                    }
                case AVMetadataKey.commonKeyTitle:
                    title = metadata.stringValue
                case AVMetadataKey.commonKeyArtist:
                    subtitle = metadata.stringValue
                default:
                    break
                }
            }
            self.image = image
            self.title = title ?? filename
            self.subtitle = subtitle ?? R.string.localizable.playlist_unknown_artist()
        }
        
    }
    
}
