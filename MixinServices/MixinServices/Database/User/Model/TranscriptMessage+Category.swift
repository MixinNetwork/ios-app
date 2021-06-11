import Foundation

extension TranscriptMessage {
    
    public enum Category: RawRepresentable, Codable, Equatable {
        
        public static let attachmentIncludedCategories: [Category] = [.image, .video, .data, .audio]
        
        case text
        case image
        case video
        case data
        case sticker
        case contact
        case audio
        case live
        case post
        case location
        case appCard
        case unknown(String)
        
        public var rawValue: String {
            switch self {
            case .text:
                return "SIGNAL_TEXT"
            case .image:
                return "SIGNAL_IMAGE"
            case .video:
                return "SIGNAL_VIDEO"
            case .data:
                return "SIGNAL_DATA"
            case .sticker:
                return "SIGNAL_STICKER"
            case .contact:
                return "SIGNAL_CONTACT"
            case .audio:
                return "SIGNAL_AUDIO"
            case .live:
                return "SIGNAL_LIVE"
            case .post:
                return "SIGNAL_POST"
            case .location:
                return "SIGNAL_LOCATION"
            case .appCard:
                return "APP_CARD"
            case .unknown(let value):
                return value
            }
        }
        
        public var includesAttachment: Bool {
            Self.attachmentIncludedCategories.contains(self)
        }
        
        public init(rawValue: String) {
            switch rawValue {
            case "SIGNAL_TEXT":
                self = .text
            case "SIGNAL_IMAGE":
                self = .image
            case "SIGNAL_VIDEO":
                self = .video
            case "SIGNAL_DATA":
                self = .data
            case "SIGNAL_STICKER":
                self = .sticker
            case "SIGNAL_CONTACT":
                self = .contact
            case "SIGNAL_AUDIO":
                self = .audio
            case "SIGNAL_LIVE":
                self = .live
            case "SIGNAL_POST":
                self = .post
            case "SIGNAL_LOCATION":
                self = .location
            case "APP_CARD":
                self = .appCard
            default:
                self = .unknown(rawValue)
            }
        }
        
        public init?(messageCategoryString: String) {
            guard let category = MessageCategory(rawValue: messageCategoryString) else {
                self = .unknown(messageCategoryString)
                return
            }
            switch category {
            case .PLAIN_TEXT, .SIGNAL_TEXT:
                self = .text
            case .SIGNAL_IMAGE, .PLAIN_IMAGE:
                self = .image
            case .SIGNAL_VIDEO, .PLAIN_VIDEO:
                self = .video
            case .SIGNAL_DATA, .PLAIN_DATA:
                self = .data
            case .SIGNAL_STICKER, .PLAIN_STICKER:
                self = .sticker
            case .SIGNAL_CONTACT, .PLAIN_CONTACT:
                self = .contact
            case .SIGNAL_AUDIO, .PLAIN_AUDIO:
                self = .audio
            case .SIGNAL_LIVE, .PLAIN_LIVE:
                self = .live
            case .SIGNAL_POST, .PLAIN_POST:
                self = .post
            case .SIGNAL_LOCATION, .PLAIN_LOCATION:
                self = .location
            case .APP_CARD:
                self = .appCard
            default:
                return nil
            }
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue == rhs.rawValue
        }
        
    }
    
}
