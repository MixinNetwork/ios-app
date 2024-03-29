import Foundation
import MixinServices

struct ExternalSharingContext {
    
    enum Content {
        
        case text(String)
        case image(URL)
        case live(TransferLiveData)
        case contact(TransferContactData)
        case post(String)
        case appCard(AppCardData)
        case sticker(_ id: String, _ isAdded: Bool?)
        
        var localizedCategory: String {
            switch self {
            case .text:
                return R.string.localizable.text()
            case .image:
                return R.string.localizable.image()
            case .live:
                return R.string.localizable.live_stream()
            case .contact:
                return R.string.localizable.contact_category()
            case .post:
                return R.string.localizable.post_sharing()
            case .appCard:
                return R.string.localizable.card()
            case .sticker:
                return R.string.localizable.sticker()
            }
        }
        
    }
    
    private struct TransferImageData: Decodable {
        let url: URL
    }
    
    let conversationId: String?
    var content: Content
    
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }
        guard let items = components.queryItems else {
            return nil
        }
        if let text = items.first(where: { $0.name == "text" })?.value {
            let clamped = String(text.prefix(maxTextMessageContentLength))
            self.content = .text(clamped)
            self.conversationId = nil
            return
        }
        guard let category = items.first(where: { $0.name == "category" })?.value else {
            return nil
        }
        guard let data = items.first(where: { $0.name == "data" })?.value else {
            return nil
        }
        switch category {
        case "text":
            if let text = data.removingPercentEncoding?.base64Decoded(), !text.isEmpty {
                let clamped = String(text.prefix(maxTextMessageContentLength))
                self.content = .text(clamped)
            } else {
                return nil
            }
        case "image":
            if let encoded = data.removingPercentEncoding, let data: TransferImageData = Self.decode(base64Encoded: encoded) {
                self.content = .image(data.url)
            } else {
                return nil
            }
        case "live":
            if let encoded = data.removingPercentEncoding, let data: TransferLiveData = Self.decode(base64Encoded: encoded) {
                self.content = .live(data)
            } else {
                return nil
            }
        case "contact":
            if let encoded = data.removingPercentEncoding, let data: TransferContactData = Self.decode(base64Encoded: encoded) {
                self.content = .contact(data)
            } else {
                return nil
            }
        case "post":
            if let text = data.removingPercentEncoding?.base64Decoded(), !text.isEmpty {
                self.content = .post(text)
            } else {
                return nil
            }
        case "app_card":
            if let encoded = data.removingPercentEncoding, let data: AppCardData = Self.decode(base64Encoded: encoded) {
                self.content = .appCard(data)
            } else {
                return nil
            }
        case "sticker":
            if let encoded = data.removingPercentEncoding {
                if let data: TransferStickerData = Self.decode(base64Encoded: encoded) {
                    self.content = .sticker(data.stickerId, nil)
                } else if let stickerId = encoded.base64Decoded().uuidString {
                    self.content = .sticker(stickerId, nil)
                } else {
                    return nil
                }
            } else {
                return nil
            }
        default:
            return nil
        }
        self.conversationId = items.first(where: { $0.name == "conversation" })?.value
    }
    
    private static func decode<T>(base64Encoded string: String) -> T? where T : Decodable {
        guard let data = Data(base64Encoded: string) else {
            return nil
        }
        return try? JSONDecoder.default.decode(T.self, from: data)
    }
    
}
