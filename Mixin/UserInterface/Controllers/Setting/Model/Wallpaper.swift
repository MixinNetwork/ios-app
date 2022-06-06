import Foundation
import MixinServices

enum Wallpaper: String, CaseIterable {
    
    static let wallpaperDidChangeNotification = Notification.Name("one.mixin.messenger.wallpaperDidChange")
    enum UserInfoKey {
        static let conversationId = "cid"
    }
    
    case custom
    case symbol
    case star
    case animal
    case plant
    
    static var defaultWallpapers: [Wallpaper] { allCases.filter { $0 != .custom } }
    static let defaultWallpaper = Wallpaper.symbol
    static let defaultImage = Wallpaper.symbol.image!
    
    static private let globalKey = "global_wallpaper"
    
    var image: UIImage? {
        switch self {
        case .custom:
            return nil
        case .symbol:
            return R.image.conversation.bg_chat_symbol()!
        case .star:
            return R.image.conversation.bg_chat_star()!
        case .animal:
            return R.image.conversation.bg_chat_animal()!
        case .plant:
            return R.image.conversation.bg_chat_plant()!
        }
    }
    
}

extension Wallpaper {
    
    static func setBuildIn(_ wallpaper: Wallpaper, key: String? = nil) {
        set(wallpaper, for: key)
    }
    
    static func setCustom(_ image: UIImage, key: String? = nil) {
        set(.custom, image: image, for: key)
    }
    
    static func image(for key: String? = nil) -> UIImage {
        let rawValue: String
        let keyValue: String
        if let key = key, let chatRawValue = AppGroupUserDefaults.User.wallpapers[key] {
            rawValue = chatRawValue
            keyValue = key
        } else if let globalRawValue = AppGroupUserDefaults.User.wallpapers[globalKey] {
            rawValue = globalRawValue
            keyValue = globalKey
        } else {
            return defaultImage
        }
        if let wallpaper = Wallpaper(rawValue: rawValue) {
            if wallpaper == .custom {
                guard let data = try? Data(contentsOf: AttachmentContainer.wallpaperURL(for: keyValue)), let image = UIImage(data: data) else {
                    return defaultImage
                }
                return image
            } else {
                return wallpaper.image ?? defaultImage
            }
        } else {
            return defaultImage
        }
    }
    
    static func get(for key: String? = nil) -> Wallpaper {
        let rawValue: String
        if let key = key, let chatRawValue = AppGroupUserDefaults.User.wallpapers[key] {
            rawValue = chatRawValue
        } else if let globalRawValue = AppGroupUserDefaults.User.wallpapers[globalKey] {
            rawValue = globalRawValue
        } else {
            return defaultWallpaper
        }
        return Wallpaper(rawValue: rawValue) ?? defaultWallpaper
    }
    
}

extension Wallpaper {
    
    private static func set(_ wallpaper: Wallpaper, image: UIImage? = nil, for key: String? = nil) {
        assert(image == nil || wallpaper == .custom)
        let key = key ?? globalKey
        let path = AttachmentContainer.wallpaperURL(for: key)
        if let image = image {
            image.saveToFile(path: path)
        } else {
            try? FileManager.default.removeItem(at: path)
        }
        AppGroupUserDefaults.User.wallpapers[key] = wallpaper.rawValue
        if key != globalKey {
            NotificationCenter.default.post(onMainThread: Self.wallpaperDidChangeNotification,
                                            object: self,
                                            userInfo: [Self.UserInfoKey.conversationId: key])
        }
    }
    
}
