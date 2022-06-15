import Foundation
import MixinServices

enum Wallpaper {
    
    enum Scope {
        
        case global
        case conversation(String)
        
        var key: String {
            switch self {
            case .global:
                return "global"
            case .conversation(let id):
                return id
            }
        }
        
    }
    
    static let wallpaperDidChangeNotification = Notification.Name("one.mixin.messenger.wallpaperDidChange")
    static let conversationIdUserInfoKey = "cid"
    
    case symbol
    case star
    case animal
    case plant
    case custom(UIImage)
    
    static let `default`: Wallpaper = .symbol
    static let official: [Wallpaper] = [.symbol, .star, .animal, .plant]
    
    var image: UIImage {
        switch self {
        case .symbol:
            return R.image.conversation.bg_chat_symbol()!
        case .star:
            return R.image.conversation.bg_chat_star()!
        case .animal:
            return R.image.conversation.bg_chat_animal()!
        case .plant:
            return R.image.conversation.bg_chat_plant()!
        case .custom(let image):
            return image
        }
    }
    
    var showMaskView: Bool {
        switch self {
        case .custom:
            return true
        default:
            return false
        }
    }
    
    static func save(_ wallpaper: Wallpaper, for scope: Scope) {
        let url = AttachmentContainer.wallpaperURL(for: scope.key)
        switch wallpaper {
        case .custom(let image):
            image.saveToFile(path: url)
        default:
            try? FileManager.default.removeItem(at: url)
        }
        AppGroupUserDefaults.User.wallpapers[scope.key] = Storage(wallpaper: wallpaper).rawValue
        if case let .conversation(id) = scope {
            NotificationCenter.default.post(onMainThread: Self.wallpaperDidChangeNotification,
                                            object: self,
                                            userInfo: [Self.conversationIdUserInfoKey: id])
        }
    }
    
    static func wallpaper(for scope: Scope) -> Wallpaper {
        let key: String
        let rawValue: String?
        switch scope {
        case .conversation:
            if let string = AppGroupUserDefaults.User.wallpapers[scope.key] {
                key = scope.key
                rawValue = string
            } else {
                fallthrough
            }
        case .global:
            key = Scope.global.key
            rawValue = AppGroupUserDefaults.User.wallpapers[key]
        }
        guard let rawValue = rawValue, let storage = Storage(rawValue: rawValue) else {
            return .default
        }
        switch storage {
        case .symbol:
            return .symbol
        case .star:
            return .star
        case .animal:
            return .animal
        case .plant:
            return .plant
        case .custom:
            let url = AttachmentContainer.wallpaperURL(for: key)
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                return .custom(image)
            } else {
                return .default
            }
        }
    }
    
    func matches(_ another: Wallpaper) -> Bool {
        Storage(wallpaper: self) == Storage(wallpaper: another)
    }
    
    func contentMode(imageViewSize: CGSize) -> UIView.ContentMode {
        switch self {
        case .custom:
            return .scaleAspectFill
        default:
            let imageSize = image.size
            let isBackgroundImageUndersized = imageViewSize.width > imageSize.width || imageViewSize.height > imageSize.height
            return isBackgroundImageUndersized ? .scaleAspectFill : .center
        }
    }
    
}
    
extension Wallpaper {
    
    private enum Storage: String {
        
        case symbol
        case star
        case animal
        case plant
        case custom
        
        init(wallpaper: Wallpaper) {
            switch wallpaper {
            case .symbol:
                self = .symbol
            case .star:
                self = .star
            case .animal:
                self = .animal
            case .plant:
                self = .plant
            case .custom:
                self = .custom
            }
        }
        
    }
    
    private var storage: Storage {
        switch self {
        case .symbol:
            return .symbol
        case .star:
            return .star
        case .animal:
            return .animal
        case .plant:
            return .plant
        case .custom:
            return .custom
        }
    }
    
}
